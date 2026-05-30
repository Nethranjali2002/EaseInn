import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';

let api: APIRequestContext;
let adminToken: string;
let staffToken: string;
let propertyId: string;
let roomId: string;
let bookingId: string;

test.describe('Booking CRUD', () => {
  test.beforeAll(async ({ playwright }) => {
    api = await playwright.request.newContext({
      extraHTTPHeaders: { 'Content-Type': 'application/json' },
    });
    const admin = await api.post(`${BASE}/auth/login`, { data: { email: 'kamal@easeinn.com', password: 'password123' } });
    adminToken = (await admin.json()).data.accessToken;
    const stf = await api.post(`${BASE}/auth/login`, { data: { email: 'dilshan@easeinn.com', password: 'password123' } });
    staffToken = (await stf.json()).data.accessToken;

    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const properties = (await props.json()).data.properties;
    for (const p of properties) {
      const rooms = await api.get(`${BASE}/properties/${p._id}/rooms`, { headers: auth() });
      const availableRoom = (await rooms.json()).data.rooms.find((r: any) => r.status === 'available');
      if (availableRoom) {
        propertyId = p._id;
        roomId = availableRoom._id;
        break;
      }
    }
  });

  const auth = (token?: string) => ({ Authorization: `Bearer ${token || adminToken}` });

  test('GET /properties/:id/bookings lists bookings', async () => {
    if (!propertyId) { test.skip(); return; }
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('POST /bookings creates booking', async () => {
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 30);
    const checkoutDate = new Date(futureDate);
    checkoutDate.setDate(checkoutDate.getDate() + 3);

    const res = await api.post(`${BASE}/bookings`, {
      data: {
        property: propertyId,
        room: roomId,
        guest: { name: 'Playwright Test Guest', email: 'pw@test.com', phone: '+94771234567' },
        checkIn: futureDate.toISOString(),
        checkOut: checkoutDate.toISOString(),
        numberOfGuests: 2,
        roomType: 'single',
      },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    bookingId = (await res.json()).data.booking._id;
  });

  test('GET /bookings/:id gets single booking', async () => {
    const res = await api.get(`${BASE}/bookings/${bookingId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.booking.guest.name).toBe('Playwright Test Guest');
  });

  test('PATCH /bookings/:id updates booking', async () => {
    const res = await api.patch(`${BASE}/bookings/${bookingId}`, {
      data: { specialRequests: 'Updated by Playwright' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
  });

  test('GET /properties/:id/bookings/stats returns stats', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('totalBookings');
  });

  test('PATCH /bookings/:id/cancel cancels booking', async () => {
    const res = await api.patch(`${BASE}/bookings/${bookingId}/cancel`, {
      data: { reason: 'Playwright test cancellation' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.booking.bookingStatus).toBe('cancelled');
  });

  test('POST /bookings blocked for staff (403)', async () => {
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 60);
    const checkout = new Date(futureDate);
    checkout.setDate(checkout.getDate() + 1);

    const res = await api.post(`${BASE}/bookings`, {
      data: {
        property: propertyId, room: roomId,
        guest: { name: 'Fail', email: 'fail@test.com' },
        checkIn: futureDate.toISOString(), checkOut: checkout.toISOString(),
        numberOfGuests: 1, roomType: 'single',
      },
      headers: auth(staffToken),
    });
    expect(res.status()).toBe(403);
  });

  test('GET /properties/:id/bookings/calendar returns calendar data', async () => {
    const now = new Date();
    const end = new Date(now);
    end.setMonth(end.getMonth() + 1);
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings/calendar?startDate=${now.toISOString()}&endDate=${end.toISOString()}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test.afterAll(async () => { await api.dispose(); });
});

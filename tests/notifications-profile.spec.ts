import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';

let api: APIRequestContext;
let adminToken: string;

test.describe('Notifications & Profile', () => {
  test.beforeAll(async ({ playwright }) => {
    api = await playwright.request.newContext({
      extraHTTPHeaders: { 'Content-Type': 'application/json' },
    });
    const admin = await api.post(`${BASE}/auth/login`, { data: { email: 'kamal@easeinn.com', password: 'password123' } });
    adminToken = (await admin.json()).data.accessToken;
  });

  const auth = () => ({ Authorization: `Bearer ${adminToken}` });

  // ===== NOTIFICATIONS =====
  test('GET /notifications lists notifications', async () => {
    const res = await api.get(`${BASE}/notifications`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.notifications.length).toBeGreaterThan(0);
  });

  test('GET /notifications/unread returns count', async () => {
    const res = await api.get(`${BASE}/notifications/unread`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data).toHaveProperty('count');
  });

  test('PATCH /notifications/:id/read marks as read', async () => {
    const list = await api.get(`${BASE}/notifications`, { headers: auth() });
    const notifs = (await list.json()).data.notifications;
    const firstNotif = notifs[0];
    if (firstNotif) {
      const res = await api.patch(`${BASE}/notifications/${firstNotif._id}/read`, { headers: auth() });
      expect(res.ok()).toBeTruthy();
    }
  });

  test('PATCH /notifications/read-all marks all as read', async () => {
    const res = await api.patch(`${BASE}/notifications/read-all`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  // ===== PROFILE =====
  test('GET /users/me returns profile', async () => {
    const res = await api.get(`${BASE}/users/me`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.user.name).toBeTruthy();
    expect(body.data.user.email).toBeTruthy();
  });

  test('PATCH /users/me updates name', async () => {
    const res = await api.patch(`${BASE}/users/me`, {
      data: { name: 'Kamal Perera Updated' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.user.name).toBe('Kamal Perera Updated');
  });

  // ===== FEEDBACK =====
  test('POST /feedback creates feedback (public)', async () => {
    // Create a fresh booking specifically for feedback testing
    const adminRes = await api.post(`${BASE}/auth/login`, { data: { email: 'kamal@easeinn.com', password: 'password123' } });
    const adminToken = (await adminRes.json()).data.accessToken;
    const adminAuth = { Authorization: `Bearer ${adminToken}` };

    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const pList = (await props.json()).data.properties;
    expect(pList.length).toBeGreaterThan(0);
    const pid = pList[0]._id;

    const roomsRes = await api.get(`${BASE}/properties/${pid}/rooms`, { headers: adminAuth });
    const rooms = (await roomsRes.json()).data.rooms;
    const room = rooms.find((r: any) => r.status === 'available');
    if (!room) { test.skip(); return; }

    // Create a fresh booking for feedback
    const future = new Date(); future.setDate(future.getDate() + 100);
    const checkout = new Date(future); checkout.setDate(checkout.getDate() + 1);
    const bkRes = await api.post(`${BASE}/bookings`, {
      data: {
        property: pid, room: room._id,
        guest: { name: 'Feedback Test', email: 'fb@test.com' },
        checkIn: future.toISOString(), checkOut: checkout.toISOString(),
        numberOfGuests: 1, roomType: room.roomType,
      },
      headers: adminAuth,
    });
    const bookingId = (await bkRes.json()).data.booking._id;

    // Now submit feedback for the fresh booking
    const res = await api.post(`${BASE}/feedback`, {
      data: { booking: bookingId, rating: 4, title: 'Playwright Test', comment: 'Good' },
    });
    expect([200, 201]).toContain(res.status());
  });

  test('GET /properties/:id/feedback lists feedback', async () => {
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const pid = (await props.json()).data.properties[0]._id;
    const res = await api.get(`${BASE}/properties/${pid}/feedback`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('POST /upload/single without file returns 400', async () => {
    const res = await api.post(`${BASE}/upload/single`, { headers: auth() });
    expect(res.status()).toBe(400);
  });

  test.afterAll(async () => { await api.dispose(); });
});

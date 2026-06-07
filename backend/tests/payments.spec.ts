import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';

let api: APIRequestContext;
let adminToken: string;
let staffToken: string;
let propertyId: string;
let bookingId: string;
let paymentId: string;

test.describe('Payment CRUD', () => {
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
      const payRes = await api.get(`${BASE}/properties/${p._id}/payments`, { headers: auth() });
      const pays = (await payRes.json()).data.payments;
      if (pays && pays.length > 0) {
        propertyId = p._id;
        const bks = await api.get(`${BASE}/properties/${p._id}/bookings?status=confirmed`, { headers: auth() });
        const bookings = (await bks.json()).data.bookings;
        if (bookings.length > 0) bookingId = bookings[0]._id;
        break;
      }
    }
    if (!propertyId && properties.length > 0) {
      propertyId = properties[0]._id;
    }
  });

  const auth = (token?: string) => ({ Authorization: `Bearer ${token || adminToken}` });

  test('GET /properties/:id/payments lists payments', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/payments`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('POST /payments creates payment', async () => {
    if (!bookingId) { test.skip(); return; }
    const res = await api.post(`${BASE}/payments`, {
      data: { booking: bookingId, amount: 5000, method: 'cash', type: 'partial', status: 'completed' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    paymentId = (await res.json()).data.payment._id;
  });

  test('GET /payments/:id gets payment detail', async () => {
    if (!paymentId) { test.skip(); return; }
    const res = await api.get(`${BASE}/payments/${paymentId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.payment.amount).toBe(5000);
  });

  test('GET /properties/:id/payments/stats returns stats', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/payments/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('totalRevenue');
  });

  test('POST /payments blocked for staff (403)', async () => {
    const res = await api.post(`${BASE}/payments`, {
      data: { booking: bookingId || '000000000000000000000000', amount: 1000, method: 'cash', type: 'advance' },
      headers: auth(staffToken),
    });
    expect(res.status()).toBe(403);
  });

  test.afterAll(async () => { await api.dispose(); });
});

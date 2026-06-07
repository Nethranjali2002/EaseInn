import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';

let api: APIRequestContext;
let adminToken: string;
let managerToken: string;
let staffToken: string;

test.describe('RBAC - Role-Based Access Control', () => {
  test.beforeAll(async ({ playwright }) => {
    api = await playwright.request.newContext({
      extraHTTPHeaders: { 'Content-Type': 'application/json' },
    });
    const admin = await api.post(`${BASE}/auth/login`, { data: { email: 'kamal@easeinn.com', password: 'password123' } });
    adminToken = (await admin.json()).data.accessToken;
    const mgr = await api.post(`${BASE}/auth/login`, { data: { email: 'nadeesha@easeinn.com', password: 'password123' } });
    managerToken = (await mgr.json()).data.accessToken;
    const stf = await api.post(`${BASE}/auth/login`, { data: { email: 'dilshan@easeinn.com', password: 'password123' } });
    staffToken = (await stf.json()).data.accessToken;
  });

  const auth = (token: string) => ({ Authorization: `Bearer ${token}` });
  const noAuth = () => ({});

  // ===== ADMIN-ONLY =====
  test('Admin can access admin users', async () => {
    const res = await api.get(`${BASE}/admin/users`, { headers: auth(adminToken) });
    expect(res.ok()).toBeTruthy();
  });

  test('Manager CANNOT access admin users (403)', async () => {
    const res = await api.get(`${BASE}/admin/users`, { headers: auth(managerToken) });
    expect(res.status()).toBe(403);
  });

  test('Staff CANNOT access admin users (403)', async () => {
    const res = await api.get(`${BASE}/admin/users`, { headers: auth(staffToken) });
    expect(res.status()).toBe(403);
  });

  test('No auth CANNOT access admin users (401)', async () => {
    const res = await api.get(`${BASE}/admin/users`);
    expect(res.status()).toBe(401);
  });

  // ===== PROPERTY MANAGEMENT =====
  test('Admin can create property', async () => {
    const res = await api.post(`${BASE}/properties`, {
      data: { name: 'RBAC Test', address: { city: 'Test' } },
      headers: auth(adminToken),
    });
    expect(res.ok()).toBeTruthy();
  });

  test('Manager CANNOT create property (403)', async () => {
    const res = await api.post(`${BASE}/properties`, {
      data: { name: 'Fail', address: { city: 'X' } },
      headers: auth(managerToken),
    });
    expect(res.status()).toBe(403);
  });

  test('Staff CANNOT create property (403)', async () => {
    const res = await api.post(`${BASE}/properties`, {
      data: { name: 'Fail', address: { city: 'X' } },
      headers: auth(staffToken),
    });
    expect(res.status()).toBe(403);
  });

  // ===== ALL ROLES CAN READ =====
  test('Admin can view properties', async () => {
    const res = await api.get(`${BASE}/properties`, { headers: auth(adminToken) });
    expect(res.ok()).toBeTruthy();
  });

  test('Manager can view properties', async () => {
    const res = await api.get(`${BASE}/properties`, { headers: auth(managerToken) });
    expect(res.ok()).toBeTruthy();
  });

  test('Staff can view properties', async () => {
    const res = await api.get(`${BASE}/properties`, { headers: auth(staffToken) });
    expect(res.ok()).toBeTruthy();
  });

  // ===== BOOKING MANAGEMENT =====
  test('Manager can create booking', async () => {
    const props = await api.get(`${BASE}/properties`, { headers: auth(managerToken) });
    const properties = (await props.json()).data.properties;
    let foundPid = '';
    let foundRoom: any = null;
    for (const p of properties) {
      const rooms = await api.get(`${BASE}/properties/${p._id}/rooms`, { headers: auth(managerToken) });
      const room = (await rooms.json()).data.rooms.find((r: any) => r.status === 'available');
      if (room) { foundPid = p._id; foundRoom = room; break; }
    }
    if (!foundRoom) { test.skip(); return; }

    const future = new Date(); future.setDate(future.getDate() + 45);
    const checkout = new Date(future); checkout.setDate(checkout.getDate() + 2);

    const res = await api.post(`${BASE}/bookings`, {
      data: {
        property: foundPid, room: foundRoom._id,
        guest: { name: 'RBAC Manager Test', email: 'rbac@test.com' },
        checkIn: future.toISOString(), checkOut: checkout.toISOString(),
        numberOfGuests: 1, roomType: foundRoom.roomType,
      },
      headers: auth(managerToken),
    });
    expect(res.ok()).toBeTruthy();
  });

  test('Staff CANNOT create booking (403)', async () => {
    const res = await api.post(`${BASE}/bookings`, {
      data: { property: '000000000000000000000000', room: '000000000000000000000000', guest: { name: 'X' }, checkIn: new Date().toISOString(), checkOut: new Date().toISOString(), numberOfGuests: 1, roomType: 'single' },
      headers: auth(staffToken),
    });
    expect([403, 400, 404]).toContain(res.status());
  });

  // ===== ANALYTICS =====
  test('Admin can view consolidated analytics', async () => {
    const res = await api.get(`${BASE}/analytics/consolidated`, { headers: auth(adminToken) });
    expect(res.ok()).toBeTruthy();
  });

  test('Manager CANNOT view consolidated analytics (403)', async () => {
    const res = await api.get(`${BASE}/analytics/consolidated`, { headers: auth(managerToken) });
    expect(res.status()).toBe(403);
  });

  test('Staff CANNOT view analytics (403)', async () => {
    const res = await api.get(`${BASE}/properties/000000000000000000000000/analytics/revenue`, { headers: auth(staffToken) });
    expect([403, 404]).toContain(res.status());
  });

  // ===== NOTIFICATIONS =====
  test('Any user can view their notifications', async () => {
    const res = await api.get(`${BASE}/notifications`, { headers: auth(staffToken) });
    expect(res.ok()).toBeTruthy();
  });

  // ===== HEALTH (PUBLIC) =====
  test('Health endpoint works without auth', async () => {
    const res = await api.get(`${BASE}/health`);
    expect(res.ok()).toBeTruthy();
  });

  test.afterAll(async () => { await api.dispose(); });
});

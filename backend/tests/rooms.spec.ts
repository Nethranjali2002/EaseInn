import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';

let api: APIRequestContext;
let adminToken: string;
let staffToken: string;
let propertyId: string;
let roomId: string;

test.describe('Room CRUD', () => {
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
    propertyId = properties.length > 0 ? properties[0]._id : '';
    if (propertyId) {
      const rooms = await api.get(`${BASE}/properties/${propertyId}/rooms`, { headers: auth() });
      const roomList = (await rooms.json()).data.rooms;
      if (roomList.length > 0) roomId = roomList[0]._id;
    }
  });

  const auth = (token?: string) => ({ Authorization: `Bearer ${token || adminToken}` });

  test('GET /properties/:id/rooms lists rooms', async () => {
    if (!propertyId) { test.skip(); return; }
    const res = await api.get(`${BASE}/properties/${propertyId}/rooms`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('POST /properties/:id/rooms creates room', async () => {
    const res = await api.post(`${BASE}/properties/${propertyId}/rooms`, {
      data: { roomNumber: 'TEST99', roomType: 'single', capacity: 1, basePrice: 5000, floor: 0 },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    roomId = (await res.json()).data.room._id;
  });

  test('PATCH /rooms/:id updates room', async () => {
    const res = await api.patch(`${BASE}/rooms/${roomId}`, {
      data: { basePrice: 6000 },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.room.basePrice).toBe(6000);
  });

  test('GET /rooms/:id gets single room', async () => {
    const res = await api.get(`${BASE}/rooms/${roomId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('DELETE /rooms/:id deletes room (admin)', async () => {
    const res = await api.delete(`${BASE}/rooms/${roomId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('POST /rooms blocked for staff (403)', async () => {
    const res = await api.post(`${BASE}/properties/${propertyId}/rooms`, {
      data: { roomNumber: 'FAIL', roomType: 'single', capacity: 1, basePrice: 5000 },
      headers: auth(staffToken),
    });
    expect(res.status()).toBe(403);
  });

  test('GET /properties/:id/rooms/available works without auth', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/rooms/available`);
    expect(res.ok()).toBeTruthy();
  });

  test.afterAll(async () => { await api.dispose(); });
});

import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';

let api: APIRequestContext;
let adminToken: string;
let managerToken: string;
let staffToken: string;
let propertyId: string;
let roomId: string;

test.describe('Property CRUD', () => {
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

  test('GET /properties lists properties for admin', async () => {
    const res = await api.get(`${BASE}/properties`, { headers: auth(adminToken) });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.properties.length).toBeGreaterThan(0);
  });

  test('POST /properties creates property (admin)', async () => {
    const res = await api.post(`${BASE}/properties`, {
      data: { name: 'Test Hotel', address: { city: 'Colombo', country: 'Sri Lanka' } },
      headers: auth(adminToken),
    });
    expect(res.ok()).toBeTruthy();
    propertyId = (await res.json()).data.property._id;
  });

  test('PATCH /properties/:id updates property (admin)', async () => {
    const res = await api.patch(`${BASE}/properties/${propertyId}`, {
      data: { name: 'Test Hotel Updated' },
      headers: auth(adminToken),
    });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.property.name).toBe('Test Hotel Updated');
  });

  test('GET /properties/:id gets single property', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}`, { headers: auth(adminToken) });
    expect(res.ok()).toBeTruthy();
  });

  test('GET /properties/:id/stats returns stats', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/stats`, { headers: auth(adminToken) });
    expect(res.ok()).toBeTruthy();
  });

  test('POST /properties blocked for manager (403)', async () => {
    const res = await api.post(`${BASE}/properties`, {
      data: { name: 'Should Fail', address: { city: 'X' } },
      headers: auth(managerToken),
    });
    expect(res.status()).toBe(403);
  });

  test('POST /properties blocked for staff (403)', async () => {
    const res = await api.post(`${BASE}/properties`, {
      data: { name: 'Should Fail', address: { city: 'X' } },
      headers: auth(staffToken),
    });
    expect(res.status()).toBe(403);
  });

  test('DELETE /properties/:id deletes property (admin)', async () => {
    const res = await api.delete(`${BASE}/properties/${propertyId}`, { headers: auth(adminToken) });
    expect(res.ok()).toBeTruthy();
  });

  test.afterAll(async () => { await api.dispose(); });
});

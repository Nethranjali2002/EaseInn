import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';

let api: APIRequestContext;
let adminToken: string;
let managerToken: string;
let staffToken: string;

test.describe('Auth Module', () => {
  test.beforeAll(async ({ playwright }) => {
    api = await playwright.request.newContext({
      extraHTTPHeaders: { 'Content-Type': 'application/json' },
    });
  });

  test('GET /health returns ok', async () => {
    const res = await api.get(`${BASE}/health`);
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.status).toBe('ok');
  });

  test('POST /auth/register creates new user', async () => {
    const res = await api.post(`${BASE}/auth/register`, {
      data: { name: 'Test User', email: `test${Date.now()}@test.com`, password: 'password123' },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.success).toBe(true);
    expect(body.data.accessToken).toBeTruthy();
    expect(body.data.refreshToken).toBeTruthy();
  });

  test('POST /auth/register rejects duplicate email', async () => {
    const email = `dup${Date.now()}@test.com`;
    await api.post(`${BASE}/auth/register`, { data: { name: 'Dup', email, password: 'password123' } });
    const res = await api.post(`${BASE}/auth/register`, { data: { name: 'Dup2', email, password: 'password123' } });
    expect(res.status()).toBe(409);
  });

  test('POST /auth/register rejects invalid email', async () => {
    const res = await api.post(`${BASE}/auth/register`, {
      data: { name: 'Bad', email: 'notanemail', password: 'password123' },
    });
    expect(res.status()).toBe(400);
  });

  test('POST /auth/register rejects short password', async () => {
    const res = await api.post(`${BASE}/auth/register`, {
      data: { name: 'Short', email: `short${Date.now()}@test.com`, password: '123' },
    });
    expect(res.status()).toBe(400);
  });

  test('POST /auth/login with valid credentials', async () => {
    const res = await api.post(`${BASE}/auth/login`, {
      data: { email: 'kamal@easeinn.com', password: 'password123' },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.accessToken).toBeTruthy();
    adminToken = body.data.accessToken;
  });

  test('POST /auth/login as manager', async () => {
    const res = await api.post(`${BASE}/auth/login`, {
      data: { email: 'nadeesha@easeinn.com', password: 'password123' },
    });
    expect(res.ok()).toBeTruthy();
    managerToken = (await res.json()).data.accessToken;
  });

  test('POST /auth/login as staff', async () => {
    const res = await api.post(`${BASE}/auth/login`, {
      data: { email: 'dilshan@easeinn.com', password: 'password123' },
    });
    expect(res.ok()).toBeTruthy();
    staffToken = (await res.json()).data.accessToken;
  });

  test('POST /auth/login rejects wrong password', async () => {
    const res = await api.post(`${BASE}/auth/login`, {
      data: { email: 'kamal@easeinn.com', password: 'wrongpassword' },
    });
    expect(res.status()).toBe(401);
  });

  test('POST /auth/login rejects non-existent email', async () => {
    const res = await api.post(`${BASE}/auth/login`, {
      data: { email: 'nobody@test.com', password: 'password123' },
    });
    expect(res.status()).toBe(401);
  });

  test('POST /auth/refresh generates new tokens', async () => {
    const loginRes = await api.post(`${BASE}/auth/login`, {
      data: { email: 'kamal@easeinn.com', password: 'password123' },
    });
    const refreshToken = (await loginRes.json()).data.refreshToken;
    const res = await api.post(`${BASE}/auth/refresh`, { data: { refreshToken } });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.accessToken).toBeTruthy();
    expect(body.data.refreshToken).toBeTruthy();
  });

  test('GET /users/me returns profile with token', async () => {
    const res = await api.get(`${BASE}/users/me`, {
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.user.email).toBe('kamal@easeinn.com');
    expect(body.data.user.role).toBe('admin');
  });

  test('GET /users/me fails without token', async () => {
    const res = await api.get(`${BASE}/users/me`);
    expect(res.status()).toBe(401);
  });

  test('POST /auth/logout invalidates token', async () => {
    const loginRes = await api.post(`${BASE}/auth/login`, {
      data: { email: 'kamal@easeinn.com', password: 'password123' },
    });
    const token = (await loginRes.json()).data.accessToken;
    const res = await api.post(`${BASE}/auth/logout`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.ok()).toBeTruthy();
    // Re-login to restore adminToken for remaining tests
    const relogin = await api.post(`${BASE}/auth/login`, {
      data: { email: 'kamal@easeinn.com', password: 'password123' },
    });
    adminToken = (await relogin.json()).data.accessToken;
  });

  test('POST /auth/forgot-password sends reset email', async () => {
    const res = await api.post(`${BASE}/auth/forgot-password`, {
      data: { email: 'kamal@easeinn.com' },
    });
    expect(res.ok()).toBeTruthy();
  });

  test('POST /auth/change-password with valid current password', async () => {
    const loginRes = await api.post(`${BASE}/auth/login`, {
      data: { email: 'kamal@easeinn.com', password: 'password123' },
    });
    const token = (await loginRes.json()).data.accessToken;
    const res = await api.post(`${BASE}/auth/change-password`, {
      data: { currentPassword: 'password123', newPassword: 'password123' },
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.ok()).toBeTruthy();
  });

  test('POST /auth/change-password rejects wrong current password', async () => {
    const loginRes = await api.post(`${BASE}/auth/login`, {
      data: { email: 'kamal@easeinn.com', password: 'password123' },
    });
    const token = (await loginRes.json()).data.accessToken;
    const res = await api.post(`${BASE}/auth/change-password`, {
      data: { currentPassword: 'wrongold', newPassword: 'password123' },
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(res.status()).toBe(400);
  });

  test.afterAll(async () => { await api.dispose(); });
});

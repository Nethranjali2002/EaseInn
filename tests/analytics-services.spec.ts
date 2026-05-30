import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';
let api: APIRequestContext;
let adminToken: string;

test.describe('Service Unit Tests', () => {
  test.beforeAll(async ({ playwright }) => {
    api = await playwright.request.newContext({ extraHTTPHeaders: { 'Content-Type': 'application/json' } });
    const res = await api.post(`${BASE}/auth/login`, { data: { email: 'kamal@easeinn.com', password: 'password123' } });
    adminToken = (await res.json()).data.accessToken;
  });

  const auth = () => ({ Authorization: `Bearer ${adminToken}` });

  test('Analytics: revenue report returns data', async () => {
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const pid = (await props.json()).data.properties[0]._id;
    const res = await api.get(`${BASE}/properties/${pid}/analytics/revenue`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('Analytics: occupancy report returns data', async () => {
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const pid = (await props.json()).data.properties[0]._id;
    const res = await api.get(`${BASE}/properties/${pid}/analytics/occupancy`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('occupancyRate');
  });

  test('Analytics: booking trends returns data', async () => {
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const properties = (await props.json()).data.properties;
    let found = false;
    for (const p of properties) {
      const res = await api.get(`${BASE}/properties/${p._id}/analytics/trends`, { headers: auth() });
      if (res.ok()) {
        const body = await res.json();
        expect(body.data).toBeDefined();
        found = true;
        break;
      }
    }
    expect(found).toBe(true);
  });

  test('Analytics: task performance returns data', async () => {
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const pid = (await props.json()).data.properties[0]._id;
    const res = await api.get(`${BASE}/properties/${pid}/analytics/tasks`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('Analytics: room type performance returns data', async () => {
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const pid = (await props.json()).data.properties[0]._id;
    const res = await api.get(`${BASE}/properties/${pid}/analytics/rooms`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('Analytics: consolidated report returns data', async () => {
    const res = await api.get(`${BASE}/analytics/consolidated`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('totalProperties');
    expect(body.data).toHaveProperty('totalRevenue');
  });

  test('AI: pricing suggestions return demand-based data', async () => {
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const properties = (await props.json()).data.properties;
    let found = false;
    for (const p of properties) {
      const res = await api.get(`${BASE}/properties/${p._id}/analytics/pricing`, { headers: auth() });
      if (res.ok()) {
        const body = await res.json();
        if (body.data.suggestions && body.data.suggestions.length > 0) {
          expect(body.data.suggestions[0]).toHaveProperty('suggestedPrice');
          expect(body.data.suggestions[0]).toHaveProperty('demandMultiplier');
          expect(body.data.suggestions[0]).toHaveProperty('factors');
          found = true;
          break;
        }
      }
    }
    expect(found).toBe(true);
  });

  test('AI: demand forecast returns historical + forecast', async () => {
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const pid = (await props.json()).data.properties[0]._id;
    const res = await api.get(`${BASE}/properties/${pid}/analytics/forecast`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('forecast');
    expect(body.data.forecast.length).toBe(3);
    expect(body.data.forecast[0]).toHaveProperty('predictedBookings');
    expect(body.data.forecast[0]).toHaveProperty('confidence');
  });

  test('Feedback: stats return rating data', async () => {
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const pid = (await props.json()).data.properties[0]._id;
    const res = await api.get(`${BASE}/properties/${pid}/feedback/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('avgRating');
    expect(body.data).toHaveProperty('totalReviews');
  });

  test('Notification: unread count works', async () => {
    const res = await api.get(`${BASE}/notifications/unread`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(typeof body.data.count).toBe('number');
  });

  test('Password: forgot password sends reset', async () => {
    const res = await api.post(`${BASE}/auth/forgot-password`, { data: { email: 'kamal@easeinn.com' } });
    expect(res.ok()).toBeTruthy();
  });

  test('Upload: single without file returns 400', async () => {
    const res = await api.post(`${BASE}/upload/single`, { headers: auth() });
    expect(res.status()).toBe(400);
  });

  test.afterAll(async () => { await api.dispose(); });
});

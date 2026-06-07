import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';

let api: APIRequestContext;
let adminToken: string;
let staffToken: string;
let propertyId: string;
let taskId: string;

test.describe('Task CRUD', () => {
  test.beforeAll(async ({ playwright }) => {
    api = await playwright.request.newContext({
      extraHTTPHeaders: { 'Content-Type': 'application/json' },
    });
    const admin = await api.post(`${BASE}/auth/login`, { data: { email: 'kamal@easeinn.com', password: 'password123' } });
    adminToken = (await admin.json()).data.accessToken;
    const stf = await api.post(`${BASE}/auth/login`, { data: { email: 'dilshan@easeinn.com', password: 'password123' } });
    staffToken = (await stf.json()).data.accessToken;

    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    propertyId = (await props.json()).data.properties[0]._id;
  });

  const auth = (token?: string) => ({ Authorization: `Bearer ${token || adminToken}` });

  test('POST /tasks creates task', async () => {
    const res = await api.post(`${BASE}/tasks`, {
      data: {
        property: propertyId,
        title: 'Playwright Test Task',
        description: 'Created by automated test',
        type: 'housekeeping',
        priority: 'high',
        subtasks: [{ title: 'Subtask 1' }, { title: 'Subtask 2' }],
        checklist: [{ item: 'Checklist A' }, { item: 'Checklist B' }],
      },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    taskId = (await res.json()).data.task._id;
  });

  test('GET /properties/:id/tasks lists tasks', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/tasks`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.tasks.length).toBeGreaterThan(0);
  });

  test('GET /tasks/:id gets single task', async () => {
    const res = await api.get(`${BASE}/tasks/${taskId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.task.title).toBe('Playwright Test Task');
    expect(body.data.task.subtasks.length).toBe(2);
    expect(body.data.task.checklist.length).toBe(2);
  });

  test('PATCH /tasks/:id updates task', async () => {
    const res = await api.patch(`${BASE}/tasks/${taskId}`, {
      data: { priority: 'urgent', notes: 'Updated by test' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
  });

  test('PATCH /tasks/:id/complete completes task', async () => {
    const res = await api.patch(`${BASE}/tasks/${taskId}/complete`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.task.status).toBe('completed');
  });

  test('GET /tasks/my returns staff tasks', async () => {
    const res = await api.get(`${BASE}/tasks/my`, { headers: auth(staffToken) });
    expect(res.ok()).toBeTruthy();
  });

  test('GET /properties/:id/tasks/stats returns stats', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/tasks/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('totalTasks');
  });

  test('POST /tasks blocked for staff (403)', async () => {
    const res = await api.post(`${BASE}/tasks`, {
      data: { property: propertyId, title: 'Fail Task' },
      headers: auth(staffToken),
    });
    expect(res.status()).toBe(403);
  });

  test.afterAll(async () => { await api.dispose(); });
});

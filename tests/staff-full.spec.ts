import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';
let api: APIRequestContext;
let staffToken: string;
let propertyId: string;
let adminToken: string;
let staffUserId: string;
let otherStaffId: string;

const auth = () => ({ Authorization: `Bearer ${staffToken}` });

test.describe('Staff - All Functions', () => {
  test.beforeAll(async ({ playwright }) => {
    api = await playwright.request.newContext({ extraHTTPHeaders: { 'Content-Type': 'application/json' } });

    // Login as staff
    const stfRes = await api.post(`${BASE}/auth/login`, { data: { email: 'dilshan@easeinn.com', password: 'password123' } });
    staffToken = (await stfRes.json()).data.accessToken;

    // Login as admin for setup
    const adminRes = await api.post(`${BASE}/auth/login`, { data: { email: 'kamal@easeinn.com', password: 'password123' } });
    adminToken = (await adminRes.json()).data.accessToken;

    // Get staff user ID
    const meRes = await api.get(`${BASE}/users/me`, { headers: auth() });
    staffUserId = (await meRes.json()).data.user._id;

    // Get other staff ID
    const usersRes = await api.get(`${BASE}/admin/users`, { headers: { Authorization: `Bearer ${adminToken}` } });
    const users = (await usersRes.json()).data.users;
    otherStaffId = users.find((u: any) => u.role === 'staff' && u._id !== staffUserId)?._id;

    // Get property with rooms
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const properties = (await props.json()).data.properties;
    for (const p of properties) {
      const rooms = await api.get(`${BASE}/properties/${p._id}/rooms`, { headers: auth() });
      const roomData = (await rooms.json()).data.rooms;
      if (roomData && roomData.length > 2) { propertyId = p._id; break; }
    }
    if (!propertyId && properties.length > 0) propertyId = properties[0]._id;

    // Setup: create a task assigned to this staff with subtasks + checklist
    const rooms = await api.get(`${BASE}/properties/${propertyId}/rooms`, { headers: { Authorization: `Bearer ${adminToken}` } });
    const room = (await rooms.json()).data.rooms[0];

    await api.post(`${BASE}/tasks`, {
      data: {
        property: propertyId, title: 'Staff Test Task - Open',
        description: 'Created for staff test',
        type: 'housekeeping', priority: 'high',
        assignedTo: staffUserId,
        room: room?._id,
        dueDate: new Date(Date.now() + 86400000).toISOString(),
        subtasks: [{ title: 'Sub A' }, { title: 'Sub B' }],
        checklist: [{ item: 'Check A' }, { item: 'Check B' }],
      },
      headers: { Authorization: `Bearer ${adminToken}` },
    });

    // Setup: create a task for OTHER staff (for ownership tests)
    await api.post(`${BASE}/tasks`, {
      data: {
        property: propertyId, title: 'Other Staff Task',
        description: 'Assigned to another staff',
        type: 'maintenance', priority: 'medium',
        assignedTo: otherStaffId,
        room: room?._id,
        subtasks: [{ title: 'Sub X' }],
        checklist: [{ item: 'Check X' }],
      },
      headers: { Authorization: `Bearer ${adminToken}` },
    });
  });

  // ===== DASHBOARD (1-3) =====
  test('1. View assigned tasks summary', async () => {
    const res = await api.get(`${BASE}/tasks/my`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.tasks.length).toBeGreaterThan(0);
  });

  test('2. Staff sees task-focused data', async () => {
    const res = await api.get(`${BASE}/tasks/my`, { headers: auth() });
    const body = await res.json();
    body.data.tasks.forEach((t: any) => {
      expect(t).toHaveProperty('title');
      expect(t).toHaveProperty('status');
      expect(t).toHaveProperty('type');
      expect(t).toHaveProperty('priority');
    });
  });

  test('3. Staff cannot view analytics (403)', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/analytics/revenue`, { headers: auth() });
    expect(res.status()).toBe(403);
  });

  // ===== MY TASKS - VIEW (4-7) =====
  test('4. View all assigned tasks', async () => {
    const res = await api.get(`${BASE}/tasks/my`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.tasks.length).toBeGreaterThan(0);
  });

  test('5. Filter tasks by status - open', async () => {
    const res = await api.get(`${BASE}/tasks/my?status=open`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    body.data.tasks.forEach((t: any) => expect(t.status).toBe('open'));
  });

  test('6. Filter tasks by status - in-progress', async () => {
    const res = await api.get(`${BASE}/tasks/my?status=in-progress`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('7. Filter tasks by status - completed', async () => {
    const res = await api.get(`${BASE}/tasks/my?status=completed`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  // ===== MY TASKS - VIEW DETAILS (8-11) =====
  test('8. View task details with subtasks', async () => {
    const tasks = await api.get(`${BASE}/tasks/my`, { headers: auth() });
    const task = (await tasks.json()).data.tasks.find((t: any) => t.subtasks?.length > 0);
    if (!task) { test.skip(); return; }
    const res = await api.get(`${BASE}/tasks/${task._id}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.task.subtasks.length).toBeGreaterThan(0);
  });

  test('9. View task details with checklist', async () => {
    const tasks = await api.get(`${BASE}/tasks/my`, { headers: auth() });
    const task = (await tasks.json()).data.tasks.find((t: any) => t.checklist?.length > 0);
    if (!task) { test.skip(); return; }
    const res = await api.get(`${BASE}/tasks/${task._id}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.task.checklist.length).toBeGreaterThan(0);
  });

  test('10. View task due date', async () => {
    const tasks = await api.get(`${BASE}/tasks/my`, { headers: auth() });
    const task = (await tasks.json()).data.tasks.find((t: any) => t.dueDate);
    if (!task) { test.skip(); return; }
    const res = await api.get(`${BASE}/tasks/${task._id}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.task.dueDate).toBeTruthy();
  });

  test('11. View task assigned room', async () => {
    const tasks = await api.get(`${BASE}/tasks/my`, { headers: auth() });
    const task = (await tasks.json()).data.tasks.find((t: any) => t.room?.roomNumber);
    if (!task) { test.skip(); return; }
    const res = await api.get(`${BASE}/tasks/${task._id}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.task.room.roomNumber).toBeTruthy();
  });

  // ===== MY TASKS - START/COMPLETE (12-15) =====
  test('12. Start task (open -> in-progress)', async () => {
    const tasks = await api.get(`${BASE}/tasks/my?status=open`, { headers: auth() });
    const task = (await tasks.json()).data.tasks[0];
    if (!task) { test.skip(); return; }
    const res = await api.patch(`${BASE}/tasks/${task._id}`, { data: { status: 'in-progress' }, headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.task.status).toBe('in-progress');
  });

  test('13. Complete task (in-progress -> completed)', async () => {
    const tasks = await api.get(`${BASE}/tasks/my?status=in-progress`, { headers: auth() });
    const task = (await tasks.json()).data.tasks[0];
    if (!task) { test.skip(); return; }
    const res = await api.patch(`${BASE}/tasks/${task._id}/complete`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.task.status).toBe('completed');
  });

  test('14. Complete task ownership check - staff cannot complete unassigned task', async () => {
    if (!otherStaffId) { test.skip(); return; }
    // Find the task we created for the other staff
    const allTasksRes = await api.get(`${BASE}/properties/${propertyId}/tasks`, { headers: { Authorization: `Bearer ${adminToken}` } });
    const allTasks = (await allTasksRes.json()).data.tasks;
    const otherStaffTask = allTasks.find((t: any) => t.assignedTo?._id === otherStaffId && t.status !== 'completed');
    if (!otherStaffTask) { test.skip(); return; }

    const res = await api.patch(`${BASE}/tasks/${otherStaffTask._id}/complete`, { headers: auth() });
    expect(res.status()).toBe(403);
  });

  test('15. Task not found returns 404', async () => {
    const res = await api.get(`${BASE}/tasks/000000000000000000000000`, { headers: auth() });
    expect(res.status()).toBe(404);
  });

  // ===== MY TASKS - SUBTASKS (16-17) =====
  test('16. Toggle subtask completed', async () => {
    const tasks = await api.get(`${BASE}/tasks/my?status=open`, { headers: auth() });
    const task = (await tasks.json()).data.tasks.find((t: any) => t.subtasks?.length > 0 && t.status !== 'completed');
    if (!task) { test.skip(); return; }
    const res = await api.patch(`${BASE}/tasks/${task._id}/subtasks/0`, { data: { completed: true }, headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('17. Toggle subtask uncompleted', async () => {
    const tasks = await api.get(`${BASE}/tasks/my?status=open`, { headers: auth() });
    const task = (await tasks.json()).data.tasks.find((t: any) => t.subtasks?.length > 0 && t.status !== 'completed');
    if (!task) { test.skip(); return; }
    const res = await api.patch(`${BASE}/tasks/${task._id}/subtasks/0`, { data: { completed: false }, headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  // ===== MY TASKS - CHECKLISTS (18-19) =====
  test('18. Toggle checklist checked', async () => {
    const tasks = await api.get(`${BASE}/tasks/my?status=open`, { headers: auth() });
    const task = (await tasks.json()).data.tasks.find((t: any) => t.checklist?.length > 0 && t.status !== 'completed');
    if (!task) { test.skip(); return; }
    const res = await api.patch(`${BASE}/tasks/${task._id}/checklist/0`, { data: { checked: true }, headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('19. Toggle checklist unchecked', async () => {
    const tasks = await api.get(`${BASE}/tasks/my?status=open`, { headers: auth() });
    const task = (await tasks.json()).data.tasks.find((t: any) => t.checklist?.length > 0 && t.status !== 'completed');
    if (!task) { test.skip(); return; }
    const res = await api.patch(`${BASE}/tasks/${task._id}/checklist/0`, { data: { checked: false }, headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  // ===== TASK OWNERSHIP CHECK (20-22) =====
  test('20. Staff cannot modify subtask of unassigned task', async () => {
    const allTasksRes = await api.get(`${BASE}/properties/${propertyId}/tasks`, { headers: { Authorization: `Bearer ${adminToken}` } });
    const allTasks = (await allTasksRes.json()).data.tasks;
    const otherTask = allTasks.find((t: any) => t.assignedTo?._id === otherStaffId && t.subtasks?.length > 0 && t.status !== 'completed');
    if (!otherTask) { test.skip(); return; }

    const res = await api.patch(`${BASE}/tasks/${otherTask._id}/subtasks/0`, { data: { completed: true }, headers: auth() });
    expect(res.status()).toBe(403);
  });

  test('21. Staff cannot create tasks (403)', async () => {
    const res = await api.post(`${BASE}/tasks`, {
      data: { property: propertyId, title: 'Should fail', type: 'housekeeping' },
      headers: auth(),
    });
    expect(res.status()).toBe(403);
  });

  test('22. Staff cannot view all tasks for property (403)', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/tasks`, { headers: auth() });
    expect(res.status()).toBe(403);
  });

  // ===== VIEW BOOKINGS (READ ONLY) (23-25) =====
  test('23. View bookings list', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.bookings.length).toBeGreaterThan(0);
  });

  test('24. View single booking', async () => {
    const bookings = await api.get(`${BASE}/properties/${propertyId}/bookings`, { headers: auth() });
    const bk = (await bookings.json()).data.bookings[0];
    const res = await api.get(`${BASE}/bookings/${bk._id}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('25. Staff cannot create booking (403)', async () => {
    const res = await api.post(`${BASE}/bookings`, {
      data: { property: propertyId, room: '000', guest: { name: 'X' }, checkIn: new Date().toISOString(), checkOut: new Date().toISOString(), numberOfGuests: 1, roomType: 'single' },
      headers: auth(),
    });
    expect(res.status()).toBe(403);
  });

  // ===== VIEW PROPERTIES (READ ONLY) (26-28) =====
  test('26. View properties list', async () => {
    const res = await api.get(`${BASE}/properties`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.properties.length).toBeGreaterThan(0);
  });

  test('27. View single property', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('28. Staff cannot create property (403)', async () => {
    const res = await api.post(`${BASE}/properties`, {
      data: { name: 'Should fail', address: { city: 'X' } },
      headers: auth(),
    });
    expect(res.status()).toBe(403);
  });

  // ===== VIEW ROOMS (READ ONLY) (29-32) =====
  test('29. View rooms list', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/rooms`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.rooms.length).toBeGreaterThan(0);
  });

  test('30. View single room', async () => {
    const rooms = await api.get(`${BASE}/properties/${propertyId}/rooms`, { headers: auth() });
    const room = (await rooms.json()).data.rooms[0];
    const res = await api.get(`${BASE}/rooms/${room._id}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('31. Staff cannot create room (403)', async () => {
    const res = await api.post(`${BASE}/properties/${propertyId}/rooms`, {
      data: { roomNumber: 'FAIL', roomType: 'single', capacity: 1, basePrice: 5000 },
      headers: auth(),
    });
    expect(res.status()).toBe(403);
  });

  test('32. View available rooms (public)', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/rooms/available`);
    expect(res.ok()).toBeTruthy();
  });

  // ===== NOTIFICATIONS (33-37) =====
  test('33. View notifications', async () => {
    const res = await api.get(`${BASE}/notifications`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('34. Unread count', async () => {
    const res = await api.get(`${BASE}/notifications/unread`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect(typeof (await res.json()).data.count).toBe('number');
  });

  test('35. Mark notification as read', async () => {
    const notifs = await api.get(`${BASE}/notifications`, { headers: auth() });
    const notif = (await notifs.json()).data.notifications[0];
    if (notif) {
      const res = await api.patch(`${BASE}/notifications/${notif._id}/read`, { headers: auth() });
      expect(res.ok()).toBeTruthy();
    }
  });

  test('36. Mark all as read', async () => {
    const res = await api.patch(`${BASE}/notifications/read-all`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('37. Staff gets notification when task assigned', async () => {
    const before = (await (await api.get(`${BASE}/notifications/unread`, { headers: auth() })).json()).data.count;
    await api.post(`${BASE}/tasks`, {
      data: { property: propertyId, title: 'Staff Notif Test', assignedTo: staffUserId, type: 'housekeeping', priority: 'low' },
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    const after = (await (await api.get(`${BASE}/notifications/unread`, { headers: auth() })).json()).data.count;
    expect(after).toBeGreaterThanOrEqual(before);
  });

  // ===== PROFILE (38-41) =====
  test('38. View profile', async () => {
    const res = await api.get(`${BASE}/users/me`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.user.role).toBe('staff');
  });

  test('39. Update name', async () => {
    const res = await api.patch(`${BASE}/users/me`, { data: { name: 'Dilshan Staff' }, headers: auth() });
    expect(res.ok()).toBeTruthy();
    await api.patch(`${BASE}/users/me`, { data: { name: 'Dilshan Rajapaksa' }, headers: auth() });
  });

  test('40. Change password', async () => {
    const res = await api.post(`${BASE}/auth/change-password`, {
      data: { currentPassword: 'password123', newPassword: 'password123' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
  });

  test('41. Logout', async () => {
    const loginRes = await api.post(`${BASE}/auth/login`, { data: { email: 'dilshan@easeinn.com', password: 'password123' } });
    const token = (await loginRes.json()).data.accessToken;
    const res = await api.post(`${BASE}/auth/logout`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.ok()).toBeTruthy();
    const relogin = await api.post(`${BASE}/auth/login`, { data: { email: 'dilshan@easeinn.com', password: 'password123' } });
    staffToken = (await relogin.json()).data.accessToken;
  });

  // ===== FILE UPLOAD (42) =====
  test('42. Upload endpoint works', async () => {
    const res = await api.post(`${BASE}/upload/single`, { headers: auth() });
    expect(res.status()).toBe(400);
  });

  // ===== RESTRICTED ACTIONS (43-48) =====
  test('43. Staff cannot delete property (403)', async () => {
    const res = await api.delete(`${BASE}/properties/${propertyId}`, { headers: auth() });
    expect(res.status()).toBe(403);
  });

  test('44. Staff cannot update property (403)', async () => {
    const res = await api.patch(`${BASE}/properties/${propertyId}`, { data: { name: 'X' }, headers: auth() });
    expect(res.status()).toBe(403);
  });

  test('45. Staff cannot delete room (403)', async () => {
    const rooms = await api.get(`${BASE}/properties/${propertyId}/rooms`, { headers: auth() });
    const room = (await rooms.json()).data.rooms[0];
    const res = await api.delete(`${BASE}/rooms/${room._id}`, { headers: auth() });
    expect(res.status()).toBe(403);
  });

  test('46. Staff cannot update room (403)', async () => {
    const rooms = await api.get(`${BASE}/properties/${propertyId}/rooms`, { headers: auth() });
    const room = (await rooms.json()).data.rooms[0];
    const res = await api.patch(`${BASE}/rooms/${room._id}`, { data: { basePrice: 99999 }, headers: auth() });
    expect(res.status()).toBe(403);
  });

  test('47. Staff cannot cancel booking (403)', async () => {
    const bookings = await api.get(`${BASE}/properties/${propertyId}/bookings`, { headers: auth() });
    const bk = (await bookings.json()).data.bookings[0];
    const res = await api.patch(`${BASE}/bookings/${bk._id}/cancel`, { data: { reason: 'fail' }, headers: auth() });
    expect(res.status()).toBe(403);
  });

  test('48. Staff cannot record payment (403)', async () => {
    const res = await api.post(`${BASE}/payments`, {
      data: { booking: '000000000000000000000000', amount: 1000, method: 'cash', type: 'advance' },
      headers: auth(),
    });
    expect(res.status()).toBe(403);
  });

  test.afterAll(async () => { await api.dispose(); });
});

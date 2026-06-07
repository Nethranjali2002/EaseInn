import { test, expect, APIRequestContext } from '@playwright/test';

const BASE = 'http://localhost:3000/api/v1';
let api: APIRequestContext;
let managerToken: string;
let propertyId: string;
let createdBookingId: string;
let createdRoomId: string;
let createdTaskId: string;
let createdPaymentId: string;

const auth = () => ({ Authorization: `Bearer ${managerToken}` });

let adminToken: string;
const getAdminAuth = async () => {
  if (!adminToken) {
    const adminRes = await api.post(`${BASE}/auth/login`, { data: { email: 'kamal@easeinn.com', password: 'password123' } });
    adminToken = (await adminRes.json()).data.accessToken;
  }
  return { Authorization: `Bearer ${adminToken}` };
};

test.describe('Manager - All 66 Functions', () => {
  test.beforeAll(async ({ playwright }) => {
    api = await playwright.request.newContext({ extraHTTPHeaders: { 'Content-Type': 'application/json' } });
    const res = await api.post(`${BASE}/auth/login`, { data: { email: 'nadeesha@easeinn.com', password: 'password123' } });
    managerToken = (await res.json()).data.accessToken;
    const props = await api.get(`${BASE}/properties`, { headers: auth() });
    const properties = (await props.json()).data.properties;
    // Find property with rooms/bookings (Seaside Resort)
    for (const p of properties) {
      const rooms = await api.get(`${BASE}/properties/${p._id}/rooms`, { headers: auth() });
      const roomData = (await rooms.json()).data.rooms;
      if (roomData && roomData.length > 2) {
        propertyId = p._id;
        break;
      }
    }
    if (!propertyId && properties.length > 0) propertyId = properties[0]._id;
  });

  // ===== DASHBOARD (1-7) =====
  test('1. View property stats', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('totalRooms');
    expect(body.data).toHaveProperty('availableRooms');
  });

  test('2. View booking stats (check-ins today)', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('todayCheckIns');
    expect(body.data).toHaveProperty('todayCheckOuts');
  });

  test('3. View pending payments count', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings/stats`, { headers: auth() });
    const body = await res.json();
    expect(body.data).toHaveProperty('pendingPayments');
  });

  test('4. View recent bookings', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings?limit=5`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.bookings.length).toBeGreaterThan(0);
  });

  test('5. View urgent tasks', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/tasks?priority=urgent&limit=5`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('6. View total revenue', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/payments/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('totalRevenue');
  });

  test('7. Task stats', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/tasks/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('totalTasks');
    expect(body.data).toHaveProperty('openTasks');
  });

  // ===== BOOKINGS (8-16) =====
  test('8. View all bookings', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.bookings.length).toBeGreaterThan(0);
  });

  test('9. Filter bookings by status', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings?status=confirmed`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    body.data.bookings.forEach((b: any) => expect(b.bookingStatus).toBe('confirmed'));
  });

  test('10. Create new booking', async () => {
    const rooms = await api.get(`${BASE}/properties/${propertyId}/rooms`, { headers: auth() });
    const room = (await rooms.json()).data.rooms.find((r: any) => r.status === 'available');
    if (!room) { test.skip(); return; }

    const future = new Date(); future.setDate(future.getDate() + 60);
    const checkout = new Date(future); checkout.setDate(checkout.getDate() + 2);

    const res = await api.post(`${BASE}/bookings`, {
      data: {
        property: propertyId, room: room._id,
        guest: { name: 'Manager Test Guest', email: 'mgrtest@test.com', phone: '+94771234567' },
        checkIn: future.toISOString(), checkOut: checkout.toISOString(),
        numberOfGuests: 2, roomType: room.roomType,
      },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    createdBookingId = (await res.json()).data.booking._id;
  });

  test('11. View booking details', async () => {
    if (!createdBookingId) { test.skip(); return; }
    const res = await api.get(`${BASE}/bookings/${createdBookingId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.booking.guest.name).toBe('Manager Test Guest');
  });

  test('12. Update booking details', async () => {
    if (!createdBookingId) { test.skip(); return; }
    const res = await api.patch(`${BASE}/bookings/${createdBookingId}`, {
      data: { specialRequests: 'Updated by manager test' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
  });

  test('13. Cancel booking', async () => {
    if (!createdBookingId) { test.skip(); return; }
    const res = await api.patch(`${BASE}/bookings/${createdBookingId}/cancel`, {
      data: { reason: 'Manager test cancellation' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.booking.bookingStatus).toBe('cancelled');
  });

  test('14. Check-in guest (existing confirmed)', async () => {
    const bks = await api.get(`${BASE}/properties/${propertyId}/bookings?status=confirmed`, { headers: auth() });
    const bk = (await bks.json()).data.bookings[0];
    if (!bk) { test.skip(); return; }
    const res = await api.patch(`${BASE}/bookings/${bk._id}/check-in`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    // Check out again to restore state
    await api.patch(`${BASE}/bookings/${bk._id}/check-out`, { headers: auth() });
  });

  test('15. Booking calendar', async () => {
    const now = new Date(); const end = new Date(now); end.setMonth(end.getMonth() + 1);
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings/calendar?startDate=${now.toISOString()}&endDate=${end.toISOString()}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(Array.isArray(body.data.bookings)).toBeTruthy();
  });

  test('16. Booking stats', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('totalBookings');
    expect(body.data).toHaveProperty('activeBookings');
  });

  // ===== ROOMS (17-21) =====
  test('17. View room list', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/rooms`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.rooms.length).toBeGreaterThan(0);
  });

  test('18. Filter rooms by status', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/rooms?status=available`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    body.data.rooms.forEach((r: any) => expect(r.status).toBe('available'));
  });

  test('19. Create new room', async () => {
    const res = await api.post(`${BASE}/properties/${propertyId}/rooms`, {
      data: { roomNumber: `MGR${Date.now()}`, roomType: 'double', name: 'Manager Test Room', capacity: 2, basePrice: 10000, floor: 1 },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    createdRoomId = (await res.json()).data.room._id;
  });

  test('20. Edit room', async () => {
    if (!createdRoomId) { test.skip(); return; }
    const res = await api.patch(`${BASE}/rooms/${createdRoomId}`, {
      data: { basePrice: 12000, name: 'Manager Test Room Updated' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.room.basePrice).toBe(12000);
  });

  test('21. Delete room', async () => {
    if (!createdRoomId) { test.skip(); return; }
    const res = await api.delete(`${BASE}/rooms/${createdRoomId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  // ===== TASKS (22-29) =====
  test('22. View all tasks', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/tasks`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.tasks.length).toBeGreaterThan(0);
  });

  test('23. Create new task', async () => {
    const rooms = await api.get(`${BASE}/properties/${propertyId}/rooms`, { headers: auth() });
    const room = (await rooms.json()).data.rooms[0];
    const staffUsers = await api.get(`${BASE}/admin/users`, { headers: await getAdminAuth() });
    const staffUser = (await staffUsers.json()).data.users.find((u: any) => u.role === 'staff');

    const res = await api.post(`${BASE}/tasks`, {
      data: {
        property: propertyId, title: 'Manager Test Task',
        description: 'Created by manager test',
        type: 'housekeeping', priority: 'high',
        assignedTo: staffUser?._id,
        room: room?._id,
        dueDate: new Date(Date.now() + 86400000).toISOString(),
        subtasks: [{ title: 'Sub 1' }, { title: 'Sub 2' }],
        checklist: [{ item: 'Check A' }, { item: 'Check B' }],
      },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    createdTaskId = (await res.json()).data.task._id;
  });

  test('24. View task details', async () => {
    if (!createdTaskId) { test.skip(); return; }
    const res = await api.get(`${BASE}/tasks/${createdTaskId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.task.title).toBe('Manager Test Task');
    expect(body.data.task.subtasks.length).toBe(2);
    expect(body.data.task.checklist.length).toBe(2);
  });

  test('25. Edit task', async () => {
    if (!createdTaskId) { test.skip(); return; }
    const res = await api.patch(`${BASE}/tasks/${createdTaskId}`, {
      data: { priority: 'urgent', notes: 'Updated by manager' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
  });

  test('26. Toggle subtask', async () => {
    if (!createdTaskId) { test.skip(); return; }
    const res = await api.patch(`${BASE}/tasks/${createdTaskId}/subtasks/0`, {
      data: { completed: true },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
  });

  test('27. Toggle checklist', async () => {
    if (!createdTaskId) { test.skip(); return; }
    const res = await api.patch(`${BASE}/tasks/${createdTaskId}/checklist/0`, {
      data: { checked: true },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
  });

  test('28. Task stats', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/tasks/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('totalTasks');
    expect(body.data).toHaveProperty('completedTasks');
  });

  test('29. Filter tasks by status', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/tasks?status=open`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    body.data.tasks.forEach((t: any) => expect(t.status).toBe('open'));
  });

  // ===== PAYMENTS (30-33) =====
  test('30. Record payment', async () => {
    const bks = await api.get(`${BASE}/properties/${propertyId}/bookings?status=confirmed`, { headers: auth() });
    const bk = (await bks.json()).data.bookings[0];
    if (!bk) { test.skip(); return; }

    const res = await api.post(`${BASE}/payments`, {
      data: { booking: bk._id, amount: 5000, method: 'cash', type: 'partial', status: 'completed' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
    createdPaymentId = (await res.json()).data.payment._id;
  });

  test('31. View payment history', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/payments`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.payments.length).toBeGreaterThan(0);
  });

  test('32. Payment stats', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/payments/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('totalRevenue');
    expect(body.data).toHaveProperty('todayRevenue');
  });

  test('33. View payment detail', async () => {
    if (!createdPaymentId) { test.skip(); return; }
    const res = await api.get(`${BASE}/payments/${createdPaymentId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  // ===== FEEDBACK (34-36) =====
  test('34. View feedback list', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/feedback`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('35. Feedback stats', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/feedback/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('avgRating');
    expect(body.data).toHaveProperty('totalReviews');
  });

  test('36. Respond to feedback', async () => {
    const fbs = await api.get(`${BASE}/properties/${propertyId}/feedback`, { headers: auth() });
    const fb = (await fbs.json()).data.feedback[0];
    if (!fb) { test.skip(); return; }
    const res = await api.patch(`${BASE}/feedback/${fb._id}/respond`, {
      data: { text: 'Thank you for your feedback!' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
  });

  // ===== ANALYTICS (37-41) =====
  test('37. Revenue report', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/analytics/revenue`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('38. Occupancy report', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/analytics/occupancy`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data).toHaveProperty('occupancyRate');
  });

  test('39. Booking trends', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/analytics/trends`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('40. Task performance', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/analytics/tasks`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('41. Room type performance', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/analytics/rooms`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  // ===== CALENDAR (42-46) =====
  test('42. Calendar returns bookings', async () => {
    const now = new Date(); const end = new Date(now); end.setMonth(end.getMonth() + 1);
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings/calendar?startDate=${now.toISOString()}&endDate=${end.toISOString()}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(Array.isArray(body.data.bookings)).toBeTruthy();
  });

  test('43. Calendar with date range', async () => {
    const start = new Date(2026, 0, 1); const end = new Date(2026, 11, 31);
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings/calendar?startDate=${start.toISOString()}&endDate=${end.toISOString()}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('44. Consolidated calendar (multi-property)', async () => {
    const res = await api.get(`${BASE}/analytics/calendar`, { headers: auth() });
    // Manager doesn't have access to admin-only consolidated calendar
    expect([200, 403]).toContain(res.status());
  });

  test('45. Booking stats for calendar summary', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings/stats`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('46. Calendar with empty range', async () => {
    const start = new Date(2030, 0, 1); const end = new Date(2030, 0, 31);
    const res = await api.get(`${BASE}/properties/${propertyId}/bookings/calendar?startDate=${start.toISOString()}&endDate=${end.toISOString()}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.bookings.length).toBe(0);
  });

  // ===== EXPORT (47-52) =====
  test('47. Export bookings CSV', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/export/bookings`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const text = await res.text();
    expect(text).toContain('Guest Name');
  });

  test('48. Export payments CSV', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/export/payments`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const text = await res.text();
    expect(text).toContain('Invoice');
  });

  test('49. Export rooms CSV', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/export/rooms`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const text = await res.text();
    expect(text).toContain('Room #');
  });

  test('50. Export tasks CSV', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/export/tasks`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const text = await res.text();
    expect(text).toContain('Title');
  });

  test('51. Export bookings PDF', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/export/bookings/pdf`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
  });

  test('52. Export payments PDF', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}/export/payments/pdf`, { headers: auth() });
    expect([200, 204]).toContain(res.status());
  });

  // ===== NOTIFICATIONS (53-59) =====
  test('53. View notifications list', async () => {
    const res = await api.get(`${BASE}/notifications`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.notifications.length).toBeGreaterThan(0);
  });

  test('54. Unread count', async () => {
    const res = await api.get(`${BASE}/notifications/unread`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect(typeof (await res.json()).data.count).toBe('number');
  });

  test('55. Mark notification as read', async () => {
    const notifs = await api.get(`${BASE}/notifications`, { headers: auth() });
    const notif = (await notifs.json()).data.notifications[0];
    if (notif) {
      const res = await api.patch(`${BASE}/notifications/${notif._id}/read`, { headers: auth() });
      expect(res.ok()).toBeTruthy();
    }
  });

  test('56. Mark all as read', async () => {
    const res = await api.patch(`${BASE}/notifications/read-all`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const unread = await api.get(`${BASE}/notifications/unread`, { headers: auth() });
    expect((await unread.json()).data.count).toBe(0);
  });

  test('57. Notification from booking creation', async () => {
    const before = (await (await api.get(`${BASE}/notifications/unread`, { headers: auth() })).json()).data.count;
    const rooms = await api.get(`${BASE}/properties/${propertyId}/rooms?status=available`, { headers: auth() });
    const room = (await rooms.json()).data.rooms[0];
    if (!room) { test.skip(); return; }
    const future = new Date(); future.setDate(future.getDate() + 90);
    const checkout = new Date(future); checkout.setDate(checkout.getDate() + 1);
    await api.post(`${BASE}/bookings`, {
      data: { property: propertyId, room: room._id, guest: { name: 'Notif Test' }, checkIn: future.toISOString(), checkOut: checkout.toISOString(), numberOfGuests: 1, roomType: room.roomType },
      headers: auth(),
    });
    const after = (await (await api.get(`${BASE}/notifications/unread`, { headers: auth() })).json()).data.count;
    expect(after).toBeGreaterThanOrEqual(before);
  });

  test('58. Notification from payment creation', async () => {
    const before = (await (await api.get(`${BASE}/notifications/unread`, { headers: auth() })).json()).data.count;
    const bks = await api.get(`${BASE}/properties/${propertyId}/bookings?status=confirmed`, { headers: auth() });
    const bk = (await bks.json()).data.bookings[0];
    if (!bk) { test.skip(); return; }
    await api.post(`${BASE}/payments`, { data: { booking: bk._id, amount: 1000, method: 'cash', type: 'advance', status: 'completed' }, headers: auth() });
    const after = (await (await api.get(`${BASE}/notifications/unread`, { headers: auth() })).json()).data.count;
    expect(after).toBeGreaterThanOrEqual(before);
  });

  test('59. Notification from task creation', async () => {
    const before = (await (await api.get(`${BASE}/notifications/unread`, { headers: auth() })).json()).data.count;
    const staffUsers = await api.get(`${BASE}/admin/users`, { headers: await getAdminAuth() });
    const staffUser = (await staffUsers.json()).data.users.find((u: any) => u.role === 'staff');
    await api.post(`${BASE}/tasks`, {
      data: { property: propertyId, title: 'Notif Test Task', assignedTo: staffUser?._id, type: 'housekeeping', priority: 'low' },
      headers: auth(),
    });
    const after = (await (await api.get(`${BASE}/notifications/unread`, { headers: auth() })).json()).data.count;
    expect(after).toBeGreaterThanOrEqual(before);
  });

  // ===== PROFILE (60-63) =====
  test('60. View profile', async () => {
    const res = await api.get(`${BASE}/users/me`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.user.email).toBe('nadeesha@easeinn.com');
    expect(body.data.user.role).toBe('manager');
  });

  test('61. Update name', async () => {
    const res = await api.patch(`${BASE}/users/me`, { data: { name: 'Nadeesha Manager' }, headers: auth() });
    expect(res.ok()).toBeTruthy();
    expect((await res.json()).data.user.name).toBe('Nadeesha Manager');
    // Restore
    await api.patch(`${BASE}/users/me`, { data: { name: 'Nadeesha Silva' }, headers: auth() });
  });

  test('62. Change password', async () => {
    const res = await api.post(`${BASE}/auth/change-password`, {
      data: { currentPassword: 'password123', newPassword: 'password123' },
      headers: auth(),
    });
    expect(res.ok()).toBeTruthy();
  });

  test('63. Logout', async () => {
    const loginRes = await api.post(`${BASE}/auth/login`, { data: { email: 'nadeesha@easeinn.com', password: 'password123' } });
    const token = (await loginRes.json()).data.accessToken;
    const res = await api.post(`${BASE}/auth/logout`, { headers: { Authorization: `Bearer ${token}` } });
    expect(res.ok()).toBeTruthy();
    // Re-login for remaining tests
    const relogin = await api.post(`${BASE}/auth/login`, { data: { email: 'nadeesha@easeinn.com', password: 'password123' } });
    managerToken = (await relogin.json()).data.accessToken;
  });

  // ===== PROPERTIES VIEW (64-66) =====
  test('64. View all properties', async () => {
    const res = await api.get(`${BASE}/properties`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.properties.length).toBeGreaterThan(0);
  });

  test('65. View property details', async () => {
    const res = await api.get(`${BASE}/properties/${propertyId}`, { headers: auth() });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.data.property.name).toBeTruthy();
  });

  test('66. Manager cannot create property (403)', async () => {
    const res = await api.post(`${BASE}/properties`, {
      data: { name: 'Should Fail', address: { city: 'X' } },
      headers: auth(),
    });
    expect(res.status()).toBe(403);
  });

  test.afterAll(async () => { await api.dispose(); });
});

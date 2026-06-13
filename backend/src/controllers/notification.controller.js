import * as notificationService from '../services/notification.service.js'; // Imports the Brain handling the Bell Icon alerts
import { sendSuccess } from '../utils/response.util.js'; // Helper for formatting JSON responses


// ==========================================
// 1. GET NOTIFICATIONS
// ==========================================
export const getNotifications = async (req, res, next) => {
  try {
    // Check if the user only wants to see unread alerts (e.g. for the dropdown menu) vs all alerts (for the full page)
    const { page, limit, unreadOnly } = req.query;
    
    // Fetch the notifications specifically for the logged-in user
    const result = await notificationService.getNotifications(req.user.sub, {
      page: parseInt(page) || 1,
      limit: parseInt(limit) || 20,
      unreadOnly: unreadOnly === 'true',
    });
    
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};


// ==========================================
// 2. MARK AS READ (Single Notification)
// ==========================================
export const markAsRead = async (req, res, next) => {
  try {
    // When the user clicks a specific alert, mark it as read in the database
    await notificationService.markAsRead(req.params.id, req.user.sub);
    return sendSuccess(res, { message: 'Marked as read' });
  } catch (err) { return next(err); }
};


// ==========================================
// 3. MARK ALL AS READ
// ==========================================
export const markAllAsRead = async (req, res, next) => {
  try {
    // When the user clicks "Mark all as read" at the top of the dropdown
    await notificationService.markAllAsRead(req.user.sub);
    return sendSuccess(res, { message: 'All marked as read' });
  } catch (err) { return next(err); }
};


// ==========================================
// 4. GET UNREAD COUNT
// ==========================================
export const getUnreadCount = async (req, res, next) => {
  try {
    // A tiny, fast endpoint just to get a number (e.g., "5") to display as a red badge over the bell icon
    const count = await notificationService.getUnreadCount(req.user.sub);
    return sendSuccess(res, { data: { count } });
  } catch (err) { return next(err); }
};

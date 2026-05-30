import * as notificationService from '../services/notification.service.js';
import { sendSuccess } from '../utils/response.util.js';

export const getNotifications = async (req, res, next) => {
  try {
    const { page, limit, unreadOnly } = req.query;
    const result = await notificationService.getNotifications(req.user.sub, {
      page: parseInt(page) || 1,
      limit: parseInt(limit) || 20,
      unreadOnly: unreadOnly === 'true',
    });
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

export const markAsRead = async (req, res, next) => {
  try {
    await notificationService.markAsRead(req.params.id, req.user.sub);
    return sendSuccess(res, { message: 'Marked as read' });
  } catch (err) { return next(err); }
};

export const markAllAsRead = async (req, res, next) => {
  try {
    await notificationService.markAllAsRead(req.user.sub);
    return sendSuccess(res, { message: 'All marked as read' });
  } catch (err) { return next(err); }
};

export const getUnreadCount = async (req, res, next) => {
  try {
    const count = await notificationService.getUnreadCount(req.user.sub);
    return sendSuccess(res, { data: { count } });
  } catch (err) { return next(err); }
};

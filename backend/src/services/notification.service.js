import Notification from '../models/notification.model.js';

export const createNotification = async ({ recipient, property, type, title, message, data, channels }) => {
  const notification = await Notification.create({
    recipient,
    property,
    type,
    title,
    message,
    data,
    channels: channels || { inApp: true },
  });
  return notification;
};

export const getNotifications = async (userId, { page = 1, limit = 20, unreadOnly = false }) => {
  const query = { recipient: userId };
  if (unreadOnly) query.read = false;

  const total = await Notification.countDocuments(query);
  const notifications = await Notification.find(query)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
  return { notifications, total, page, limit };
};

export const markAsRead = async (notificationId, userId) => {
  const notification = await Notification.findOneAndUpdate(
    { _id: notificationId, recipient: userId },
    { read: true, readAt: new Date() },
    { new: true }
  );
  return notification;
};

export const markAllAsRead = async (userId) => {
  await Notification.updateMany(
    { recipient: userId, read: false },
    { read: true, readAt: new Date() }
  );
};

export const getUnreadCount = async (userId) => {
  return Notification.countDocuments({ recipient: userId, read: false });
};

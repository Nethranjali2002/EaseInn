import Notification from '../models/notification.model.js'; // The database model for the bell icon alerts


// ==========================================
// 1. CREATE NOTIFICATION
// Silently creates an alert that will pop up in the bell icon dropdown
// ==========================================
export const createNotification = async ({ recipient, property, type, title, message, data, channels }) => {
  // Create the notification record in the database
  const notification = await Notification.create({
    recipient, // The User ID (e.g., the manager who needs to see this)
    property,  // The Hotel ID this relates to
    type,      // e.g., 'booking_created', 'payment_failed', 'task_assigned'
    title,     // Short bold text
    message,   // The actual description text
    data,      // Extra invisible data (like the Booking ID) so the frontend can make the alert clickable
    channels: channels || { inApp: true }, // Defaults to showing inside the web app
  });
  return notification;
};


// ==========================================
// 2. GET NOTIFICATIONS
// Fetches the alerts for the dropdown menu
// ==========================================
export const getNotifications = async (userId, { page = 1, limit = 20, unreadOnly = false }) => {
  // Build a query that only fetches alerts for the currently logged-in user
  const query = { recipient: userId };
  
  // If the frontend specifically asks for unread ones (e.g., to power the red badge counter), filter it
  if (unreadOnly) query.read = false;

  const total = await Notification.countDocuments(query);
  
  const notifications = await Notification.find(query)
    .sort({ createdAt: -1 }) // Newest alerts at the top
    .skip((page - 1) * limit) // Pagination logic
    .limit(limit);
    
  return { notifications, total, page, limit };
};


// ==========================================
// 3. MARK AS READ (Single Alert)
// Removes the blue "new" dot from a specific alert when clicked
// ==========================================
export const markAsRead = async (notificationId, userId) => {
  // Update it in the database and explicitly log exactly when they read it
  const notification = await Notification.findOneAndUpdate(
    { _id: notificationId, recipient: userId }, // Security check: Ensure they own this alert before marking it read
    { read: true, readAt: new Date() },
    { new: true }
  );
  return notification;
};


// ==========================================
// 4. MARK ALL AS READ
// A quick action to clear out the whole inbox
// ==========================================
export const markAllAsRead = async (userId) => {
  // Find every single unread alert owned by this user and instantly flip them to read
  await Notification.updateMany(
    { recipient: userId, read: false },
    { read: true, readAt: new Date() }
  );
};


// ==========================================
// 5. GET UNREAD COUNT
// Powers the little red number on the bell icon in the navigation bar
// ==========================================
export const getUnreadCount = async (userId) => {
  // A blazing fast query that just returns a single integer (e.g., "3")
  return Notification.countDocuments({ recipient: userId, read: false });
};

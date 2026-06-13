import Notification from '../models/notification.model.js'; // The database model that powers the little "bell" icon in the UI
import User from '../models/user.model.js'; // The database model for staff/managers
import { sendEmail } from './email.util.js'; // Email helper
import { sendSMS, sendBookingSMS } from './sms.util.js'; // SMS helper
import logger from './logger.util.js'; // Server logging


// ==========================================
// 1. SEND PUSH NOTIFICATION (Core Engine)
// The master function. It can simultaneously drop a message in the database (for the bell icon),
// send an email, AND send a text message, depending on what `channels` are requested.
// ==========================================
export const sendPushNotification = async (userId, { title, message, data, channels }) => {
  try {
    // 1. Always create the in-app notification for the bell icon
    const notification = await Notification.create({
      recipient: userId,
      type: data?.type || 'system',
      title,
      message,
      data,
      channels: channels || { inApp: true }, // Default to only in-app if nothing is specified
      sent: true,
      sentAt: new Date(),
    });

    // 2. If the sender explicitly asked to send an email, and provided an email address, send it
    if (channels?.email && data?.email) {
      await sendEmail({ to: data.email, subject: title, html: `<p>${message}</p>` }).catch(() => {});
    }

    // 3. If the sender explicitly asked to send an SMS, and provided a phone number, send it
    if (channels?.sms && data?.phone) {
      await sendSMS(data.phone, message).catch(() => {});
    }

    return notification;
  } catch (error) {
    logger.error(`Push notification failed: ${error.message}`);
  }
};


// ==========================================
// 2. SEND BOOKING CONFIRMATION NOTIFICATION
// A massive "broadcast" function triggered when a new reservation is made.
// It ensures everyone (the creator, the managers, the guest) is kept in the loop.
// ==========================================
export const sendBookingConfirmationNotification = async (booking) => {
  // A. Notify the staff member who typed in the booking (so they know it saved successfully)
  await sendPushNotification(booking.createdBy, {
    title: 'Booking Confirmed',
    message: `Booking for ${booking.guest?.name} has been confirmed`,
    data: { type: 'booking_confirmed', bookingId: booking._id },
    channels: { inApp: true, email: true },
  });

  // B. Notify ALL Managers and Admins (so leadership knows money is coming in)
  try {
    // Find every single active manager in the system
    const managers = await User.find({
      role: { $in: ['admin', 'manager'] },
      isActive: true,
      status: 'Active',
    }).select('_id');

    const creatorId = booking.createdBy?.toString();
    
    // Blast out notifications in parallel to speed things up
    await Promise.all(
      managers
        // Filter out the person who created the booking (they already got notified in step A)
        .filter((m) => m._id.toString() !== creatorId)
        .map((m) =>
          sendPushNotification(m._id, {
            title: 'Booking Confirmed',
            message: `Booking for ${booking.guest?.name} has been confirmed`,
            data: { type: 'booking_confirmed', bookingId: booking._id },
            channels: { inApp: true },
          }).catch(() => {})
        )
    );
  } catch (err) {
    logger.error(`Manager notification for booking confirmation failed: ${err.message}`);
  }

  // C. Send a Welcome SMS directly to the Guest's phone
  if (booking.guest?.phone) {
    sendBookingSMS(booking.guest.phone, booking.guest.name, {
      checkIn: booking.checkIn,
      room: booking.room,
    }).catch((err) => logger.error(`Booking SMS failed: ${err.message}`));
  }
};


// ==========================================
// 3. SEND PAYMENT RECEIVED NOTIFICATION
// Broadcasts to management when money hits the account
// ==========================================
export const sendPaymentReceivedNotification = async (payment) => {
  // A. Notify the staff member who pressed "Accept Cash"
  await sendPushNotification(payment.recordedBy, {
    title: 'Payment Received',
    message: `LKR ${payment.amount} received via ${payment.method}`,
    data: { type: 'payment_received', paymentId: payment._id },
    channels: { inApp: true },
  });

  // B. Notify all managers
  try {
    const managers = await User.find({
      role: { $in: ['admin', 'manager'] },
      isActive: true,
      status: 'Active',
    }).select('_id');

    const recorderId = payment.recordedBy?.toString();
    await Promise.all(
      managers
        .filter((m) => m._id.toString() !== recorderId)
        .map((m) =>
          sendPushNotification(m._id, {
            title: 'Payment Received',
            message: `LKR ${payment.amount} received via ${payment.method}`,
            data: { type: 'payment_received', paymentId: payment._id },
            channels: { inApp: true },
          }).catch(() => {})
        )
    );
  } catch (err) {
    logger.error(`Manager notification for payment received failed: ${err.message}`);
  }
};


// ==========================================
// 4. SEND TASK ASSIGNED NOTIFICATION
// Pings a housekeeper/maintenance worker when a manager gives them a chore
// ==========================================
export const sendTaskAssignedNotification = async (task) => {
  if (!task.assignedTo) return; // If nobody is assigned, do nothing

  // A. Notify the specific staff member who was assigned the job
  await sendPushNotification(task.assignedTo, {
    title: 'New Task Assigned',
    message: task.title,
    data: { type: 'task_assigned', taskId: task._id },
    channels: { inApp: true },
  });

  // B. Notify all managers (so leadership has visibility into what chores are being assigned)
  try {
    const managers = await User.find({
      role: { $in: ['admin', 'manager'] },
      isActive: true,
      status: 'Active',
    }).select('_id');

    const assigneeId = task.assignedTo?.toString();
    await Promise.all(
      managers
        .filter((m) => m._id.toString() !== assigneeId) // Don't notify the assignee twice if they happen to be a manager
        .map((m) =>
          sendPushNotification(m._id, {
            title: 'Task Assigned',
            message: `"${task.title}" has been assigned to staff`,
            data: { type: 'task_assigned', taskId: task._id },
            channels: { inApp: true },
          }).catch(() => {})
        )
    );
  } catch (err) {
    logger.error(`Manager notification for task assignment failed: ${err.message}`);
  }
};


// ==========================================
// 5. SEND TASK COMPLETED NOTIFICATION
// Pings management when a housekeeper finishes their job
// ==========================================
export const sendTaskCompletedNotification = async (task) => {
  // A. Notify the specific manager who originally requested the chore
  if (task.assignedBy) {
    await sendPushNotification(task.assignedBy, {
      title: 'Task Completed',
      message: `"${task.title}" has been completed`,
      data: { type: 'task_completed', taskId: task._id },
      channels: { inApp: true },
    });
  }

  // B. Notify all other managers
  try {
    const managers = await User.find({
      role: { $in: ['admin', 'manager'] },
      isActive: true,
      status: 'Active',
    }).select('_id');

    const creatorId = task.assignedBy?.toString();
    const completerId = task.completedBy?.toString(); // Don't notify the person who just completed it
    
    await Promise.all(
      managers
        .filter((m) => {
          const id = m._id.toString();
          return id !== creatorId && id !== completerId;
        })
        .map((m) =>
          sendPushNotification(m._id, {
            title: 'Task Completed',
            message: `"${task.title}" has been completed`,
            data: { type: 'task_completed', taskId: task._id },
            channels: { inApp: true },
          }).catch(() => {})
        )
    );
  } catch (err) {
    logger.error(`Manager notification for task completion failed: ${err.message}`);
  }
};

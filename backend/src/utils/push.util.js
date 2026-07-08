import Notification from '../models/notification.model.js'; 
import User from '../models/user.model.js'; 
import { sendEmail } from './email.util.js'; 
import { sendSMS, sendBookingSMS } from './sms.util.js'; 
import logger from './logger.util.js'; 


export const sendPushNotification = async (userId, { title, message, data, channels }) => {
  try {
    const notification = await Notification.create({
      recipient: userId,
      type: data?.type || 'system',
      title,
      message,
      data,
      channels: channels || { inApp: true },
      sent: true,
      sentAt: new Date(),
    });

    if (channels?.email && data?.email) {
      await sendEmail({ to: data.email, subject: title, html: `<p>${message}</p>` }).catch(() => {});
    }

    if (channels?.sms && data?.phone) {
      await sendSMS(data.phone, message).catch(() => {});
    }

    return notification;
  } catch (error) {
    logger.error(`Push notification failed: ${error.message}`);
  }
};


export const sendBookingConfirmationNotification = async (booking) => {
  await sendPushNotification(booking.createdBy, {
    title: 'Booking Confirmed',
    message: `Booking for ${booking.guest?.name} has been confirmed`,
    data: { type: 'booking_confirmed', bookingId: booking._id },
    channels: { inApp: true, email: true },
  });

  try {
    const managers = await User.find({
      role: { $in: ['admin', 'manager'] },
      isActive: true,
      status: 'Active',
    }).select('_id');

    const creatorId = booking.createdBy?.toString();
    
    await Promise.all(
      managers
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

  if (booking.guest?.phone) {
    sendBookingSMS(booking.guest.phone, booking.guest.name, {
      checkIn: booking.checkIn,
      room: booking.room,
    }).catch((err) => logger.error(`Booking SMS failed: ${err.message}`));
  }
};


export const sendPaymentReceivedNotification = async (payment) => {
  await sendPushNotification(payment.recordedBy, {
    title: 'Payment Received',
    message: `LKR ${payment.amount} received via ${payment.method}`,
    data: { type: 'payment_received', paymentId: payment._id },
    channels: { inApp: true },
  });

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


export const sendTaskCompletedNotification = async (task) => {
  if (task.assignedBy) {
    await sendPushNotification(task.assignedBy, {
      title: 'Task Completed',
      message: `"${task.title}" has been completed`,
      data: { type: 'task_completed', taskId: task._id },
      channels: { inApp: true },
    });
  }

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

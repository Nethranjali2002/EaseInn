import Notification from '../models/notification.model.js';
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

  // Send SMS to guest if phone number is available
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
};

export const sendTaskAssignedNotification = async (task) => {
  if (!task.assignedTo) return;
  await sendPushNotification(task.assignedTo, {
    title: 'New Task Assigned',
    message: task.title,
    data: { type: 'task_assigned', taskId: task._id },
    channels: { inApp: true },
  });
};

export const sendTaskCompletedNotification = async (task) => {
  if (!task.assignedBy) return;
  await sendPushNotification(task.assignedBy, {
    title: 'Task Completed',
    message: `"${task.title}" has been completed`,
    data: { type: 'task_completed', taskId: task._id },
    channels: { inApp: true },
  });
};

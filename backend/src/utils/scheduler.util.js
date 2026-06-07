import Booking from '../models/booking.model.js';
import Room from '../models/room.model.js';
import { sendCheckInReminderSMS, sendPaymentReminderSMS } from './sms.util.js';
import logger from './logger.util.js';

const ONE_HOUR = 60 * 60 * 1000;
const TWENTY_FOUR_HOURS = 24 * 60 * 60 * 1000;

export const startScheduler = () => {
  // Run every hour
  setInterval(async () => {
    try {
      await sendCheckInReminders();
      await sendPaymentReminders();
    } catch (err) {
      logger.error(`Scheduler error: ${err.message}`);
    }
  }, ONE_HOUR);

  logger.info('Scheduler started - checking reminders every hour');
};

const sendCheckInReminders = async () => {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0);

  const dayAfterTomorrow = new Date(tomorrow);
  dayAfterTomorrow.setDate(dayAfterTomorrow.getDate() + 1);

  const upcomingCheckIns = await Booking.find({
    checkIn: { $gte: tomorrow, $lt: dayAfterTomorrow },
    bookingStatus: 'confirmed',
  }).populate('room', 'roomNumber');

  for (const booking of upcomingCheckIns) {
    if (booking.guest?.phone) {
      sendCheckInReminderSMS(booking.guest.phone, booking.guest.name, booking.checkIn).catch((err) =>
        logger.error(`Check-in reminder SMS failed for booking ${booking._id}: ${err.message}`)
      );
    }
  }

  if (upcomingCheckIns.length > 0) {
    logger.info(`Sent ${upcomingCheckIns.length} check-in reminders`);
  }
};

const sendPaymentReminders = async () => {
  const pendingPayments = await Booking.find({
    paymentStatus: { $in: ['pending', 'partial'] },
    bookingStatus: { $in: ['confirmed', 'pending-payment'] },
    checkIn: { $lte: new Date(Date.now() + TWENTY_FOUR_HOURS * 3) },
  });

  for (const booking of pendingPayments) {
    const outstandingAmount = (booking.pricing?.totalAmount || 0) - (booking.amountPaid || 0);
    if (outstandingAmount > 0 && booking.guest?.phone) {
      sendPaymentReminderSMS(booking.guest.phone, booking.guest.name, outstandingAmount).catch((err) =>
        logger.error(`Payment reminder SMS failed for booking ${booking._id}: ${err.message}`)
      );
    }
  }

  if (pendingPayments.length > 0) {
    logger.info(`Sent ${pendingPayments.length} payment reminders`);
  }
};

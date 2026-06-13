import Booking from '../models/booking.model.js';
import Room from '../models/room.model.js';
import { sendCheckInReminderSMS, sendPaymentReminderSMS } from './sms.util.js';
import logger from './logger.util.js';

// Time definitions in milliseconds
const ONE_HOUR = 60 * 60 * 1000;
const TWENTY_FOUR_HOURS = 24 * 60 * 60 * 1000;

// ==========================================
// 1. START SCHEDULER (The Heartbeat)
// This function is triggered once when the server boots up (in server.js).
// It acts as a never-ending clock, waking up every hour to see if automated tasks need to be run.
// ==========================================
export const startScheduler = () => {
  // `setInterval` executes the code block repeatedly at the specified interval
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


// ==========================================
// 2. SEND CHECK IN REMINDERS
// Looks for guests arriving exactly tomorrow and sends them a text message.
// ==========================================
const sendCheckInReminders = async () => {
  // Calculate the time window for "tomorrow"
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(0, 0, 0, 0); // Start of tomorrow (12:00 AM)

  const dayAfterTomorrow = new Date(tomorrow);
  dayAfterTomorrow.setDate(dayAfterTomorrow.getDate() + 1); // Start of the next day

  // Find all confirmed bookings checking in between tomorrow at 12:00AM and tomorrow at 11:59PM
  const upcomingCheckIns = await Booking.find({
    checkIn: { $gte: tomorrow, $lt: dayAfterTomorrow },
    bookingStatus: 'confirmed',
  }).populate('room', 'roomNumber');

  // Loop through each booking and send the SMS
  for (const booking of upcomingCheckIns) {
    if (booking.guest?.phone) {
      sendCheckInReminderSMS(booking.guest.phone, booking.guest.name, booking.checkIn).catch((err) =>
        logger.error(`Check-in reminder SMS failed for booking ${booking._id}: ${err.message}`)
      );
    }
  }

  // Keep a log of how many texts were sent for monitoring purposes
  if (upcomingCheckIns.length > 0) {
    logger.info(`Sent ${upcomingCheckIns.length} check-in reminders`);
  }
};


// ==========================================
// 3. SEND PAYMENT REMINDERS
// Hunts down guests who still owe money and are arriving in the next 3 days.
// ==========================================
const sendPaymentReminders = async () => {
  // Find bookings that haven't paid fully AND are checking in within 72 hours
  const pendingPayments = await Booking.find({
    paymentStatus: { $in: ['pending', 'partial'] },
    bookingStatus: { $in: ['confirmed', 'pending-payment'] },
    checkIn: { $lte: new Date(Date.now() + TWENTY_FOUR_HOURS * 3) }, // Less than 3 days from right now
  });

  for (const booking of pendingPayments) {
    // Calculate exactly how much they owe right now
    const outstandingAmount = (booking.pricing?.totalAmount || 0) - (booking.amountPaid || 0);
    
    // If they owe money and have a phone number, nudge them
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

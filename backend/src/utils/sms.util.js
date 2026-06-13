import twilio from 'twilio'; // The industry standard API for sending text messages
import { env } from '../config/env.config.js'; // Secure credentials (Twilio API keys)
import logger from './logger.util.js';

let client;
// Only try to connect to Twilio if the admin actually typed their API keys into the .env file.
// If they didn't, we just skip it gracefully instead of crashing the whole hotel server.
if (env.twilioAccountSid && env.twilioAuthToken) {
  client = twilio(env.twilioAccountSid, env.twilioAuthToken);
}


// ==========================================
// 1. SEND S M S (Core Engine)
// The raw function that actually shoots the text message out into the real world.
// ==========================================
export const sendSMS = async (to, body) => {
  if (!client) {
    logger.warn('Twilio not configured - skipping SMS send');
    return;
  }
  try {
    await client.messages.create({
      body, // The text itself (e.g. "Your room is ready")
      from: env.twilioPhoneNumber, // The hotel's automated phone number
      to, // The guest's phone number
    });
    logger.info(`SMS sent to ${to}`);
  } catch (error) {
    logger.error(`SMS send failed: ${error.message}`);
  }
};


// ==========================================
// 2. SEND BOOKING S M S
// Sent the second the guest clicks "Pay Now" to give them instant peace of mind.
// ==========================================
export const sendBookingSMS = async (phone, guestName, booking) => {
  await sendSMS(phone, `Hi ${guestName}, your booking is confirmed! Check-in: ${new Date(booking.checkIn).toLocaleDateString()}. Room: ${booking.room?.roomNumber || 'TBD'}. Thank you for choosing EaseInn!`);
};


// ==========================================
// 3. SEND PAYMENT REMINDER S M S
// Automatically triggered by the `scheduler.util.js` 3 days before arrival if they haven't fully paid.
// ==========================================
export const sendPaymentReminderSMS = async (phone, guestName, amount) => {
  await sendSMS(phone, `Hi ${guestName}, reminder: You have an outstanding balance of LKR ${amount.toFixed(2)}. Please complete payment before check-in. - EaseInn`);
};


// ==========================================
// 4. SEND CHECK IN REMINDER S M S
// Automatically triggered by the `scheduler.util.js` the day before arrival.
// ==========================================
export const sendCheckInReminderSMS = async (phone, guestName, checkInDate) => {
  await sendSMS(phone, `Hi ${guestName}, your check-in is tomorrow (${new Date(checkInDate).toLocaleDateString()}). Please bring a valid ID. See you at EaseInn!`);
};


// ==========================================
// 5. SEND TASK ASSIGNED S M S
// Optional feature: Pings a staff member's personal phone when a manager gives them a chore.
// ==========================================
export const sendTaskAssignedSMS = async (phone, staffName, taskTitle, roomNumber) => {
  await sendSMS(phone, `Hi ${staffName}, new task assigned: "${taskTitle}" for Room ${roomNumber}. Please check the app for details. - EaseInn`);
};

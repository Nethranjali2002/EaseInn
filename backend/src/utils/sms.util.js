import twilio from 'twilio';
import { env } from '../config/env.config.js';
import logger from './logger.util.js';

let client;
if (env.twilioAccountSid && env.twilioAuthToken) {
  client = twilio(env.twilioAccountSid, env.twilioAuthToken);
}

export const sendSMS = async (to, body) => {
  if (!client) {
    logger.warn('Twilio not configured - skipping SMS send');
    return;
  }
  try {
    await client.messages.create({
      body,
      from: env.twilioPhoneNumber,
      to,
    });
    logger.info(`SMS sent to ${to}`);
  } catch (error) {
    logger.error(`SMS send failed: ${error.message}`);
  }
};

export const sendBookingSMS = async (phone, guestName, booking) => {
  await sendSMS(phone, `Hi ${guestName}, your booking is confirmed! Check-in: ${new Date(booking.checkIn).toLocaleDateString()}. Room: ${booking.room?.roomNumber || 'TBD'}. Thank you for choosing EaseInn!`);
};

export const sendPaymentReminderSMS = async (phone, guestName, amount) => {
  await sendSMS(phone, `Hi ${guestName}, reminder: You have an outstanding balance of LKR ${amount.toFixed(2)}. Please complete payment before check-in. - EaseInn`);
};

export const sendCheckInReminderSMS = async (phone, guestName, checkInDate) => {
  await sendSMS(phone, `Hi ${guestName}, your check-in is tomorrow (${new Date(checkInDate).toLocaleDateString()}). Please bring a valid ID. See you at EaseInn!`);
};

export const sendTaskAssignedSMS = async (phone, staffName, taskTitle, roomNumber) => {
  await sendSMS(phone, `Hi ${staffName}, new task assigned: "${taskTitle}" for Room ${roomNumber}. Please check the app for details. - EaseInn`);
};

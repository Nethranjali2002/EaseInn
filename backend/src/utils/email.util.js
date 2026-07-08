import nodemailer from 'nodemailer'; 
import { env } from '../config/env.config.js'; 
import logger from './logger.util.js'; 

// 1. TRANSPORTER CONFIGURATION
const transporter = nodemailer.createTransport({
  host: env.emailHost || 'smtp.gmail.com',
  port: parseInt(env.emailPort) || 587, 
  secure: false,
  auth: {
    user: env.emailUser, 
    pass: env.emailPass, 
  },
});

const from = env.emailFrom || 'EaseInn <noreply@easeinn.com>';

// 2. CORE EMAIL SENDER UTILITY
export const sendEmail = async ({ to, subject, html }) => {
  if (!env.emailUser) {
    logger.warn('Email service not configured - skipping email send');
    return;
  }
  try {
    await transporter.sendMail({ from, to, subject, html });
    logger.info(`Email sent to ${to}: ${subject}`);
  } catch (error) {
    logger.error(`Email send failed: ${error.message}`);
  }
};



export const sendBookingConfirmation = async (guestEmail, guestName, booking) => {
  await sendEmail({
    to: guestEmail,
    subject: `Booking Confirmed - ${booking.property?.name || 'EaseInn'}`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #1B5E20;">Booking Confirmed!</h2>
        <p>Dear ${guestName},</p>
        <p>Your reservation has been confirmed. Here are the details:</p>
        <table style="width: 100%; border-collapse: collapse;">
          <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Check-in:</strong></td><td>${new Date(booking.checkIn).toLocaleDateString()}</td></tr>
          <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Check-out:</strong></td><td>${new Date(booking.checkOut).toLocaleDateString()}</td></tr>
          <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Room:</strong></td><td>${booking.room?.roomNumber || 'N/A'}</td></tr>
          <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Guests:</strong></td><td>${booking.numberOfGuests}</td></tr>
          <tr><td style="padding: 8px; border-bottom: 1px solid #eee;"><strong>Total:</strong></td><td>LKR ${booking.pricing?.totalAmount?.toFixed(2) || '0.00'}</td></tr>
        </table>
        <p style="margin-top: 20px;">Thank you for choosing EaseInn!</p>
      </div>
    `,
  });
};


export const sendPaymentReminder = async (guestEmail, guestName, booking, amountDue) => {
  await sendEmail({
    to: guestEmail,
    subject: `Payment Reminder - EaseInn`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #FF6F00;">Payment Reminder</h2>
        <p>Dear ${guestName},</p>
        <p>This is a friendly reminder that you have an outstanding balance of <strong>LKR ${amountDue.toFixed(2)}</strong> for your booking.</p>
        <p>Please complete your payment before your check-in date.</p>
        <p>Thank you!</p>
      </div>
    `,
  });
};


export const sendCheckInReminder = async (guestEmail, guestName, booking) => {
  await sendEmail({
    to: guestEmail,
    subject: `Check-in Reminder - EaseInn`,
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #1B5E20;">Check-in Reminder</h2>
        <p>Dear ${guestName},</p>
        <p>Your check-in is scheduled for <strong>${new Date(booking.checkIn).toLocaleDateString()}</strong>.</p>
        <p>Please bring a valid ID document for verification.</p>
        <p>We look forward to welcoming you!</p>
      </div>
    `,
  });
};


export const sendReviewInvitation = async (guestEmail, guestName, { propertyName, roomNumber, checkIn, checkOut, reviewLink }) => {
  await sendEmail({
    to: guestEmail,
    subject: `How was your stay at ${propertyName}? ⭐ Share your experience`,
    html: `
      <div style="font-family: 'Arial', sans-serif; max-width: 600px; margin: 0 auto; background: #f9f9f9; border-radius: 12px; overflow: hidden;">
        <div style="background: #1B5E20; padding: 32px 40px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px;">🏨 EaseInn</h1>
          <p style="color: rgba(255,255,255,0.8); margin: 8px 0 0;">Thank you for your stay!</p>
        </div>
        <div style="padding: 40px;">
          <h2 style="color: #1B5E20; margin-top: 0;">Dear ${guestName},</h2>
          <p style="color: #555; line-height: 1.6;">
            We hope you had a wonderful stay at <strong>${propertyName}</strong>. Your comfort and satisfaction are our top priority.
          </p>
          <div style="background: white; border: 1px solid #e0e0e0; border-radius: 8px; padding: 20px; margin: 24px 0;">
            <p style="margin: 0 0 8px; color: #888; font-size: 13px;">YOUR STAY</p>
            <p style="margin: 0 0 4px; color: #333;"><strong>Property:</strong> ${propertyName}</p>
            <p style="margin: 0 0 4px; color: #333;"><strong>Room:</strong> ${roomNumber}</p>
            <p style="margin: 0 0 4px; color: #333;"><strong>Check-in:</strong> ${new Date(checkIn).toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</p>
            <p style="margin: 0; color: #333;"><strong>Check-out:</strong> ${new Date(checkOut).toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</p>
          </div>
          <p style="color: #555; line-height: 1.6;">
            We'd love to hear your honest feedback. Your review helps us improve and helps other guests make informed decisions.
          </p>
          <div style="text-align: center; margin: 32px 0;">
            <div style="font-size: 32px; margin-bottom: 16px;">⭐⭐⭐⭐⭐</div>
            <a href="${reviewLink}" style="
              display: inline-block;
              background: #1B5E20;
              color: white;
              padding: 16px 40px;
              border-radius: 8px;
              text-decoration: none;
              font-weight: bold;
              font-size: 16px;
              letter-spacing: 0.5px;
            ">Leave a Review</a>
          </div>
          <p style="color: #999; font-size: 12px; text-align: center;">
            This review link expires in <strong>30 days</strong>. You can only submit one review per stay.
          </p>
        </div>
        <div style="background: #f0f0f0; padding: 16px 40px; text-align: center;">
          <p style="color: #aaa; font-size: 11px; margin: 0;">
            EaseInn Property Management System &bull; This email was sent because you recently checked out from one of our properties.
          </p>
        </div>
      </div>
    `,
  });
};

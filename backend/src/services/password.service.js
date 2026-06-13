import crypto from 'crypto'; // Built-in Node tool for generating random secure strings
import User from '../models/user.model.js'; // DB Model
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP errors
import { sendEmail } from '../utils/email.util.js'; // Helper that connects to Nodemailer/SendGrid to send actual emails
import { env } from '../config/env.config.js'; // Environment variables


// ==========================================
// 1. FORGOT PASSWORD
// Generates a secure, temporary token and emails it to the user
// ==========================================
export const forgotPassword = async (email) => {
  // Find the user by email (making sure to check lowercase so "John@Email.com" equals "john@email.com")
  const user = await User.findOne({ email: email.toLowerCase() });
  
  // If the email isn't in our database, stop here
  if (!user) throw new AppError('No account with that email', 404);

  // Generate a random, cryptographically secure 32-byte string. This is the token that will be put in the URL.
  const resetToken = crypto.randomBytes(32).toString('hex');
  
  // SECURITY: Hash the token BEFORE saving it to the database. 
  // If a hacker steals the database, they will only see the hashed tokens, not the ones that actually work in the URL.
  const resetTokenHash = crypto.createHash('sha256').update(resetToken).digest('hex');

  // Save the hashed token and an expiration time (15 minutes from now) to the user's DB record
  user.passwordResetToken = resetTokenHash;
  user.passwordResetExpires = Date.now() + 15 * 60 * 1000;
  
  // Save without triggering the full Mongoose validation (since we aren't changing their password yet)
  await user.save({ validateBeforeSave: false });

  // Create the exact URL the user needs to click. Uses localhost for testing, or the real domain in production.
  const resetUrl = `${env.frontendUrl || 'http://localhost:3000'}/reset-password?token=${resetToken}`;

  // Fire off the email to the user
  await sendEmail({
    to: user.email,
    subject: 'Password Reset - EaseInn',
    html: `
      <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
        <h2 style="color:#1B5E20;">Password Reset</h2>
        <p>You requested a password reset. Click the button below to reset your password:</p>
        <a href="${resetUrl}" style="display:inline-block;padding:12px 24px;background:#1B5E20;color:white;text-decoration:none;border-radius:8px;margin:16px 0;">Reset Password</a>
        <p style="color:#757575;font-size:13px;">This link expires in 15 minutes. If you didn't request this, please ignore this email.</p>
      </div>
    `,
  });

  return { message: 'Reset link sent to email' };
};


// ==========================================
// 2. RESET PASSWORD
// Takes the token from the email link and the new password, and saves it
// ==========================================
export const resetPassword = async (token, newPassword) => {
  // Hash the token the user sent in the URL so we can compare it to the hashed one saved in the database
  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

  // Look for a user who has this exact hashed token AND the expiration time is still in the future (> Date.now())
  const user = await User.findOne({
    passwordResetToken: tokenHash,
    passwordResetExpires: { $gt: Date.now() },
  });

  // If we can't find them, it means the token was fake, typed wrong, or the 15 minutes ran out
  if (!user) throw new AppError('Invalid or expired reset token', 400);

  // Set the new password. (The User model will automatically re-hash this before saving to the DB)
  user.password = newPassword;
  
  // Wipe the reset token and expiration time so this link can never be used again
  user.passwordResetToken = undefined;
  user.passwordResetExpires = undefined;
  
  // SECURITY: Wipe their refresh token. This forces all their other devices (phones, laptops) to log out immediately.
  user.refreshToken = undefined;
  
  await user.save();

  return { message: 'Password reset successful' };
};


// ==========================================
// 3. CHANGE PASSWORD
// Allows a logged-in user to change their password by providing their old one
// ==========================================
export const changePassword = async (userId, currentPassword, newPassword) => {
  // Find the user and specifically request the password field (since it's normally hidden by default)
  const user = await User.findById(userId).select('+password');
  if (!user) throw new AppError('User not found', 404);

  // Check if the "old password" they typed matches what we currently have in the DB
  const isMatch = await user.comparePassword(currentPassword);
  if (!isMatch) throw new AppError('Current password is incorrect', 400);

  // Update it. (Again, the Mongoose model will automatically hash it)
  user.password = newPassword;
  
  // Force all other devices to log out for security
  user.refreshToken = undefined;
  await user.save();

  return { message: 'Password changed successfully' };
};

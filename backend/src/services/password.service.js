import crypto from 'crypto'; 
import User from '../models/user.model.js'; 
import { AppError } from '../middlewares/error.middleware.js'; 
import { sendEmail } from '../utils/email.util.js'; 
import { env } from '../config/env.config.js'; 



export const forgotPassword = async (email) => {
  const user = await User.findOne({ email: email.toLowerCase() });
  
  if (!user) throw new AppError('No account with that email', 404);

  const resetToken = crypto.randomBytes(32).toString('hex');
  
  const resetTokenHash = crypto.createHash('sha256').update(resetToken).digest('hex');

  user.passwordResetToken = resetTokenHash;
  user.passwordResetExpires = Date.now() + 15 * 60 * 1000;
  
  await user.save({ validateBeforeSave: false });

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



export const resetPassword = async (token, newPassword) => {
  const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

  const user = await User.findOne({
    passwordResetToken: tokenHash,
    passwordResetExpires: { $gt: Date.now() },
  });

  if (!user) throw new AppError('Invalid or expired reset token', 400);

  user.password = newPassword;
  
  user.passwordResetToken = undefined;
  user.passwordResetExpires = undefined;
  
  user.refreshToken = undefined;
  
  await user.save();

  return { message: 'Password reset successful' };
};


export const changePassword = async (userId, currentPassword, newPassword) => {
  const user = await User.findById(userId).select('+password');
  if (!user) throw new AppError('User not found', 404);

  const isMatch = await user.comparePassword(currentPassword);
  if (!isMatch) throw new AppError('Current password is incorrect', 400);

  user.password = newPassword;
  
  user.refreshToken = undefined;
  await user.save();

  return { message: 'Password changed successfully' };
};

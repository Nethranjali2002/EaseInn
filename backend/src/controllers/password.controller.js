import * as passwordService from '../services/password.service.js'; // Imports the secure logic for handling password resets
import { sendSuccess } from '../utils/response.util.js'; // Helper for formatting JSON responses


// ==========================================
// 1. FORGOT PASSWORD
// ==========================================
export const forgotPassword = async (req, res, next) => {
  try {
    // Pass the user's email to the Service. The service will generate a secure reset token
    // and email it to them (using our email.util.js).
    const result = await passwordService.forgotPassword(req.body.email);
    
    // We send a generic success message even if the email doesn't exist, to prevent hackers from guessing registered emails.
    return sendSuccess(res, { message: result.message });
  } catch (err) { return next(err); }
};


// ==========================================
// 2. RESET PASSWORD
// ==========================================
export const resetPassword = async (req, res, next) => {
  try {
    // Pass the reset token (from the user's email link) and their new password to the Service
    // The service will hash the new password and save it to MongoDB
    const result = await passwordService.resetPassword(req.body.token, req.body.password);
    return sendSuccess(res, { message: result.message });
  } catch (err) { return next(err); }
};


// ==========================================
// 3. CHANGE PASSWORD (While logged in)
// ==========================================
export const changePassword = async (req, res, next) => {
  try {
    // If the user is already logged in, they provide their old password and their new one.
    // The Service checks if the old one is correct before updating the database.
    const result = await passwordService.changePassword(req.user.sub, req.body.currentPassword, req.body.newPassword);
    return sendSuccess(res, { message: result.message });
  } catch (err) { return next(err); }
};

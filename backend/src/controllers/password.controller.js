import * as passwordService from '../services/password.service.js';
import { sendSuccess } from '../utils/response.util.js';

export const forgotPassword = async (req, res, next) => {
  try {
    const result = await passwordService.forgotPassword(req.body.email);
    return sendSuccess(res, { message: result.message });
  } catch (err) { return next(err); }
};

export const resetPassword = async (req, res, next) => {
  try {
    const result = await passwordService.resetPassword(req.body.token, req.body.password);
    return sendSuccess(res, { message: result.message });
  } catch (err) { return next(err); }
};

export const changePassword = async (req, res, next) => {
  try {
    const result = await passwordService.changePassword(req.user.sub, req.body.currentPassword, req.body.newPassword);
    return sendSuccess(res, { message: result.message });
  } catch (err) { return next(err); }
};

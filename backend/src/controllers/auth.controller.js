import * as authService from '../services/auth.service.js';
import { sendSuccess } from '../utils/response.util.js';
import { logAudit } from '../utils/audit.util.js';

export const register = async (req, res, next) => {
  try {
    const { user, accessToken, refreshToken } = await authService.register(req.body);
    await logAudit({ user: user._id, action: 'register', entity: 'User', entityId: user._id, description: `New user registered: ${user.email}`, ip: req.ip, userAgent: req.get('user-agent') });
    return sendSuccess(res, {
      statusCode: 201,
      message: 'Registration successful',
      data: { user, accessToken, refreshToken },
    });
  } catch (err) {
    return next(err);
  }
};

export const login = async (req, res, next) => {
  try {
    const { user, accessToken, refreshToken } = await authService.login(req.body);
    return sendSuccess(res, {
      message: 'Login successful',
      data: { user, accessToken, refreshToken },
    });
  } catch (err) {
    return next(err);
  }
};

export const refresh = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;
    const tokens = await authService.refreshAccessToken(refreshToken);
    return sendSuccess(res, {
      message: 'Token refreshed',
      data: tokens,
    });
  } catch (err) {
    return next(err);
  }
};

export const logout = async (req, res, next) => {
  try {
    await authService.logout(req.user.sub);
    await logAudit({ user: req.user.sub, action: 'logout', entity: 'User', entityId: req.user.sub, description: 'User logged out', ip: req.ip, userAgent: req.get('user-agent') });
    return sendSuccess(res, { message: 'Logged out successfully' });
  } catch (err) {
    return next(err);
  }
};

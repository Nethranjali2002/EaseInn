import jwt from 'jsonwebtoken';
import env from '../config/env.config.js';
import { AppError } from './error.middleware.js';
import User from '../models/user.model.js';

export const authenticate = async (req, _res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return next(new AppError('Authentication required', 401));
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, env.jwt.secret);

    const user = await User.findById(decoded.sub).select('isActive status role');
    if (!user) {
      return next(new AppError('User account no longer exists', 401));
    }
    if (user.isActive === false || user.status === 'Inactive' || user.status === 'Suspended') {
      return next(new AppError('Your account has been deactivated. Please contact an administrator.', 403));
    }

    req.user = { sub: decoded.sub, role: user.role };
    return next();
  } catch (err) {
    if (err instanceof AppError) return next(err);
    return next(new AppError('Invalid or expired token', 401));
  }
};

export const authorize = (...roles) => (req, _res, next) => {
  if (!roles.includes(req.user?.role)) {
    return next(new AppError('Insufficient permissions', 403));
  }
  return next();
};

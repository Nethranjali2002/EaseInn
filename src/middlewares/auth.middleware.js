import jwt from 'jsonwebtoken';
import env from '../config/env.config.js';
import { AppError } from './error.middleware.js';

export const authenticate = (req, _res, next) => {
  const authHeader = req.headers.authorization;

  if (!authHeader?.startsWith('Bearer ')) {
    return next(new AppError('Authentication required', 401));
  }

  const token = authHeader.split(' ')[1];

  try {
    const decoded = jwt.verify(token, env.jwt.secret);
    req.user = decoded;
    return next();
  } catch {
    return next(new AppError('Invalid or expired token', 401));
  }
};

export const authorize = (...roles) => (req, _res, next) => {
  if (!roles.includes(req.user?.role)) {
    return next(new AppError('Insufficient permissions', 403));
  }
  return next();
};

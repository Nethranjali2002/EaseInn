import jwt from 'jsonwebtoken';
import User from '../models/user.model.js';
import env from '../config/env.config.js';
import { AppError } from '../middlewares/error.middleware.js';
import { checkAccountLockout, recordFailedAttempt, clearFailedAttempts } from '../utils/accountLockout.js';

const generateTokens = (userId, role) => {
  const accessToken = jwt.sign({ sub: userId, role }, env.jwt.secret, {
    expiresIn: env.jwt.expiresIn,
  });
  const refreshToken = jwt.sign({ sub: userId }, env.jwt.secret, {
    expiresIn: env.jwt.refreshExpiresIn,
  });
  return { accessToken, refreshToken };
};

export const register = async ({ name, email, password }) => {
  const existing = await User.findOne({ email });
  if (existing) throw new AppError('Email already registered', 409);

  const user = await User.create({ name, email, password });
  const tokens = generateTokens(user._id, user.role);

  user.refreshToken = tokens.refreshToken;
  await user.save();

  return { user, ...tokens };
};

export const login = async ({ email, password }) => {
  await checkAccountLockout(email);

  const user = await User.findOne({ email }).select('+password');
  if (!user || !(await user.comparePassword(password))) {
    await recordFailedAttempt(email);
    throw new AppError('Invalid email or password', 401);
  }

  await clearFailedAttempts(email);

  const tokens = generateTokens(user._id, user.role);

  user.refreshToken = tokens.refreshToken;
  await user.save();

  return { user, ...tokens };
};

export const refreshAccessToken = async (token) => {
  if (!token) throw new AppError('Refresh token required', 400);

  let decoded;
  try {
    decoded = jwt.verify(token, env.jwt.secret);
  } catch {
    throw new AppError('Invalid or expired refresh token', 401);
  }

  const user = await User.findById(decoded.sub).select('+refreshToken');
  if (!user || user.refreshToken !== token) {
    throw new AppError('Invalid refresh token', 401);
  }

  const tokens = generateTokens(user._id, user.role);

  user.refreshToken = tokens.refreshToken;
  await user.save();

  return tokens;
};

export const logout = async (userId) => {
  await User.findByIdAndUpdate(userId, { refreshToken: null });
};

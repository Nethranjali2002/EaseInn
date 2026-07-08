import jwt from 'jsonwebtoken'; 
import User from '../models/user.model.js'; 
import env from '../config/env.config.js'; 
import { AppError } from '../middlewares/error.middleware.js'; 
import { checkAccountLockout, recordFailedAttempt, clearFailedAttempts } from '../utils/accountLockout.js'; 



// 1. GENERATE TOKENS (Helper)

const generateTokens = (userId, role) => {
  const accessToken = jwt.sign({ sub: userId, role }, env.jwt.secret, {
    expiresIn: env.jwt.expiresIn,
  });
  
  const refreshToken = jwt.sign({ sub: userId }, env.jwt.secret, {
    expiresIn: env.jwt.refreshExpiresIn,
  });
  
  return { accessToken, refreshToken };
};


// 2. REGISTER
// Creates a new staff member account

export const register = async ({ name, email, password }) => {
  const existing = await User.findOne({ email });
  if (existing) throw new AppError('Email already registered', 409);

  const user = await User.create({ name, email, password });
  
  const tokens = generateTokens(user._id, user.role);

  user.refreshToken = tokens.refreshToken;
  await user.save();

  return { user, ...tokens };
};


// 3. LOGIN
// Verifies credentials and issues tokens
export const login = async ({ email, password }) => {
  await checkAccountLockout(email);

  const user = await User.findOne({ email }).select('+password');
  
  if (!user || !(await user.comparePassword(password))) {
    await recordFailedAttempt(email);
    throw new AppError('Invalid email or password', 401);
  }

  if (user.isActive === false || user.status === 'Inactive' || user.status === 'Suspended') {
    throw new AppError('Your account has been deactivated. Please contact an administrator.', 403);
  }

  await clearFailedAttempts(email);

  const tokens = generateTokens(user._id, user.role);

  user.lastLogin = new Date();
  user.refreshToken = tokens.refreshToken;
  await user.save();

  return { user, ...tokens };
};



// 4. REFRESH ACCESS TOKEN
// When a frontend's access token expires, they hit this to get a new one

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


// 5. LOGOUT
// Destroys the refresh token so it can't be used again

export const logout = async (userId) => {

  await User.findByIdAndUpdate(userId, { refreshToken: null });
};

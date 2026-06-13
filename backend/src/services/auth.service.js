import jwt from 'jsonwebtoken'; // Tool for creating and verifying secure tokens
import User from '../models/user.model.js'; // DB Model for Staff/Admins
import env from '../config/env.config.js'; // Imports our secrets like the JWT key
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP errors
import { checkAccountLockout, recordFailedAttempt, clearFailedAttempts } from '../utils/accountLockout.js'; // Security helpers to stop brute-force hacking


// ==========================================
// 1. GENERATE TOKENS (Helper)
// Creates both the short-lived Access Token and the long-lived Refresh Token
// ==========================================
const generateTokens = (userId, role) => {
  // The access token is what the frontend attaches to every API request. It expires quickly (e.g., 15 mins).
  const accessToken = jwt.sign({ sub: userId, role }, env.jwt.secret, {
    expiresIn: env.jwt.expiresIn,
  });
  
  // The refresh token is stored securely. If the access token expires, the frontend uses this to get a new one without forcing the user to log in again.
  const refreshToken = jwt.sign({ sub: userId }, env.jwt.secret, {
    expiresIn: env.jwt.refreshExpiresIn,
  });
  
  return { accessToken, refreshToken };
};


// ==========================================
// 2. REGISTER
// Creates a new staff member account
// ==========================================
export const register = async ({ name, email, password }) => {
  // Check if someone with this email already exists to prevent duplicates
  const existing = await User.findOne({ email });
  if (existing) throw new AppError('Email already registered', 409);

  // Create the new user in the database. The password will automatically be hashed by the Mongoose model before saving.
  const user = await User.create({ name, email, password });
  
  // Generate their login tokens so they don't have to log in immediately after registering
  const tokens = generateTokens(user._id, user.role);

  // Save the refresh token to their database record so we can verify it later
  user.refreshToken = tokens.refreshToken;
  await user.save();

  return { user, ...tokens };
};


// ==========================================
// 3. LOGIN
// Verifies credentials and issues tokens
// ==========================================
export const login = async ({ email, password }) => {
  // SECURITY: Check if this IP address or email has tried to log in too many times recently and failed. If so, block them.
  await checkAccountLockout(email);

  // Find the user by email. We explicitly ask MongoDB for the password field because it's usually hidden.
  const user = await User.findOne({ email }).select('+password');
  
  // If the user doesn't exist, OR the password they typed doesn't match the hashed one in the DB...
  if (!user || !(await user.comparePassword(password))) {
    // Record that they failed so we can lock them out if they keep guessing
    await recordFailedAttempt(email);
    throw new AppError('Invalid email or password', 401);
  }

  // Check if an Admin has suspended this staff member or deactivated their account
  if (user.isActive === false || user.status === 'Inactive' || user.status === 'Suspended') {
    throw new AppError('Your account has been deactivated. Please contact an administrator.', 403);
  }

  // Success! Clear their bad guesses counter
  await clearFailedAttempts(email);

  // Give them a new set of keys (tokens)
  const tokens = generateTokens(user._id, user.role);

  // Update their "last seen" timestamp and save the new refresh token to the DB
  user.lastLogin = new Date();
  user.refreshToken = tokens.refreshToken;
  await user.save();

  return { user, ...tokens };
};


// ==========================================
// 4. REFRESH ACCESS TOKEN
// When a frontend's access token expires, they hit this to get a new one
// ==========================================
export const refreshAccessToken = async (token) => {
  if (!token) throw new AppError('Refresh token required', 400);

  let decoded;
  try {
    // Verify that the token was mathematically created by our server and hasn't expired
    decoded = jwt.verify(token, env.jwt.secret);
  } catch {
    throw new AppError('Invalid or expired refresh token', 401);
  }

  // Find the user. We need to check if the refresh token they sent matches the one we saved in their database record.
  const user = await User.findById(decoded.sub).select('+refreshToken');
  if (!user || user.refreshToken !== token) {
    // If it doesn't match, they might be using a stolen token that was invalidated. Block them.
    throw new AppError('Invalid refresh token', 401);
  }

  // Issue a fresh pair of keys
  const tokens = generateTokens(user._id, user.role);

  // Save the new refresh token to the DB (this ensures old tokens can't be reused)
  user.refreshToken = tokens.refreshToken;
  await user.save();

  return tokens;
};


// ==========================================
// 5. LOGOUT
// Destroys the refresh token so it can't be used again
// ==========================================
export const logout = async (userId) => {
  // Erase the refresh token from their database record. 
  // (The access token will naturally expire on its own shortly after).
  await User.findByIdAndUpdate(userId, { refreshToken: null });
};

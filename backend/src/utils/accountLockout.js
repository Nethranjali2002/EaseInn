import AccountLockout from '../models/accountLockout.model.js'; // The database model that tracks failed logins
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP errors
import logger from './logger.util.js'; // Server logging tool

// Security Configuration
const MAX_ATTEMPTS = 5; // How many times a user can guess their password incorrectly before being blocked
const LOCKOUT_DURATION = 15 * 60 * 1000; // How long they are blocked for (15 minutes in milliseconds)


// ==========================================
// 1. CHECK ACCOUNT LOCKOUT
// Runs before a user tries to log in to see if they are currently serving a "timeout"
// ==========================================
export const checkAccountLockout = async (email) => {
  // Look up their email in the penalty box (case-insensitive)
  const record = await AccountLockout.findOne({ email: email.toLowerCase() });
  
  // If they aren't in the penalty box, let them proceed
  if (!record) return;

  // If they are in the penalty box, and their timeout hasn't expired yet
  if (record.lockedUntil && record.lockedUntil > new Date()) {
    // Calculate exactly how many minutes are left on their punishment
    const minutesLeft = Math.ceil((record.lockedUntil - Date.now()) / 60000);
    // Throw a 423 Locked error, stopping the login process immediately
    throw new AppError(`Account locked. Try again in ${minutesLeft} minutes.`, 423);
  }

  // If their timeout has expired (the current time is past the lockedUntil time)
  if (record.lockedUntil && record.lockedUntil <= new Date()) {
    // Erase their record from the penalty box so they can try again with a clean slate
    await AccountLockout.deleteOne({ email: email.toLowerCase() });
  }
};


// ==========================================
// 2. RECORD FAILED ATTEMPT
// Runs immediately after a user types the wrong password
// ==========================================
export const recordFailedAttempt = async (email) => {
  // Find their record and increment the 'attempts' counter by 1. 
  // If they don't have a record yet, create one ($setOnInsert).
  const record = await AccountLockout.findOneAndUpdate(
    { email: email.toLowerCase() },
    { $inc: { attempts: 1 }, $setOnInsert: { email: email.toLowerCase() } },
    { upsert: true, new: true } // upsert = true means "create if it doesn't exist"
  );

  // If they just hit the maximum number of allowed guesses
  if (record.attempts >= MAX_ATTEMPTS) {
    // Stamp the record with a `lockedUntil` timestamp 15 minutes into the future
    await AccountLockout.findOneAndUpdate(
      { email: email.toLowerCase() },
      { $set: { lockedUntil: new Date(Date.now() + LOCKOUT_DURATION) } }
    );
    // Alert the system administrators that someone might be trying to hack an account
    logger.warn(`Account locked after ${MAX_ATTEMPTS} failed attempts: ${email}`);
  }
};


// ==========================================
// 3. CLEAR FAILED ATTEMPTS
// Runs immediately after a user successfully logs in
// ==========================================
export const clearFailedAttempts = async (email) => {
  // Since they proved they know the password, wipe away any previous failed guesses
  await AccountLockout.deleteOne({ email: email.toLowerCase() });
};

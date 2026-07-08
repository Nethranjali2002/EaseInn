import AccountLockout from '../models/accountLockout.model.js'; // The database model that tracks failed logins
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP errors
import logger from './logger.util.js'; // Server logging tool

const MAX_ATTEMPTS = 5; 
const LOCKOUT_DURATION = 15 * 60 * 1000; 


export const checkAccountLockout = async (email) => {
  const record = await AccountLockout.findOne({ email: email.toLowerCase() });
  
  if (!record) return;

  if (record.lockedUntil && record.lockedUntil > new Date()) {
    const minutesLeft = Math.ceil((record.lockedUntil - Date.now()) / 60000);
    throw new AppError(`Account locked. Try again in ${minutesLeft} minutes.`, 423);
  }

  if (record.lockedUntil && record.lockedUntil <= new Date()) {
    await AccountLockout.deleteOne({ email: email.toLowerCase() });
  }
};


export const recordFailedAttempt = async (email) => {
  const record = await AccountLockout.findOneAndUpdate(
    { email: email.toLowerCase() },
    { $inc: { attempts: 1 }, $setOnInsert: { email: email.toLowerCase() } },
    { upsert: true, new: true } 
  );

  if (record.attempts >= MAX_ATTEMPTS) {
    await AccountLockout.findOneAndUpdate(
      { email: email.toLowerCase() },
      { $set: { lockedUntil: new Date(Date.now() + LOCKOUT_DURATION) } }
    );
    logger.warn(`Account locked after ${MAX_ATTEMPTS} failed attempts: ${email}`);
  }
};


export const clearFailedAttempts = async (email) => {
  await AccountLockout.deleteOne({ email: email.toLowerCase() });
};

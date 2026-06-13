import mongoose from 'mongoose';

// ==========================================
// ACCOUNT LOCKOUT SCHEMA
// The "Penalty Box" table. Stores temporary bans for users who forgot their password and guessed wrong too many times.
// ==========================================
const accountLockoutSchema = new mongoose.Schema(
  {
    // The email address of the person trying to log in. Must be completely lowercase so "John@Email.com" and "john@email.com" are treated equally.
    email: { type: String, required: true, unique: true, lowercase: true, index: true },
    
    // How many times have they guessed incorrectly so far?
    attempts: { type: Number, default: 0 },
    
    // If they hit the maximum limit, what exact time are they allowed to try again? (Usually 15 minutes in the future)
    lockedUntil: { type: Date },
  },
  { timestamps: true }
);

const AccountLockout = mongoose.model('AccountLockout', accountLockoutSchema);
export default AccountLockout;

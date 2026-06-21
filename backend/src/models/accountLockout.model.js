import mongoose from 'mongoose';

const accountLockoutSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, unique: true, lowercase: true, index: true },
    attempts: { type: Number, default: 0 },
    lockedUntil: { type: Date },
  },
  { timestamps: true }
);

const AccountLockout = mongoose.model('AccountLockout', accountLockoutSchema);
export default AccountLockout;

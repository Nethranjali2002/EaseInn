import mongoose from 'mongoose';
import bcrypt from 'bcryptjs'; // Library used to mathematically scramble passwords so they can never be stolen

// ==========================================
// USER SCHEMA
// Represents a staff member logging into the backend dashboard (Admins, Managers, Housekeepers).
// NOTE: Guests do NOT have accounts in this system.
// ==========================================
const userSchema = new mongoose.Schema(
  {
    // Auto-generated employee ID (e.g. "EMP-0001")
    code: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    
    // ==========================================
    // CORE AUTHENTICATION
    // ==========================================
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      maxlength: 100,
    },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true, // No two employees can share an email
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Invalid email format'], // Regex to ensure it looks like an email
    },
    
    // The scrambled password. `select: false` is a CRITICAL SECURITY feature.
    // It means if we do `User.find()`, Mongoose will intentionally hide the password field by default so it never accidentally leaks to the frontend.
    password: {
      type: String,
      required: [true, 'Password is required'],
      minlength: 8,
      select: false, 
    },
    
    // Determines what buttons and pages they can see in the UI
    role: {
      type: String,
      enum: ['admin', 'manager', 'staff'],
      default: 'staff',
    },
    
    // Security toggle: If false, they cannot log in at all (Soft delete)
    isActive: {
      type: Boolean,
      default: true,
    },
    
    // ==========================================
    // HR & PERSONAL INFORMATION
    // ==========================================
    employeeId: { type: String, trim: true }, // The hotel's internal HR number
    dateOfBirth: { type: String },
    gender: { type: String },
    nicPassport: { type: String, trim: true }, // National Identity Card
    phone: { type: String, trim: true },
    address: { type: String },
    city: { type: String },
    district: { type: String },
    postalCode: { type: String },
    
    // Employment details
    joinDate: { type: String },
    employmentType: {
      type: String,
      enum: ['Full Time', 'Part Time', 'Contract'],
      default: 'Full Time',
    },
    
    // Which specific hotel branch do they work at? (Admins might not have one, meaning they oversee all)
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
    },
    
    // Emergency Contact
    emergencyName: { type: String },
    emergencyRelationship: { type: String },
    emergencyPhone: { type: String },
    
    // ==========================================
    // FILES & METADATA
    // ==========================================
    profileImage: { type: String, default: '' },
    
    status: {
      type: String,
      enum: ['Active', 'Inactive', 'Suspended'],
      default: 'Active',
    },
    lastLogin: { type: Date },
    
    // URLs to files stored in ImgBB
    nicCopy: { type: String },
    agreement: { type: String },
    certificates: { type: String },
    
    // Used for keeping users logged in for long periods securely
    refreshToken: {
      type: String,
      select: false, // Hidden by default for security
    },
  },
  {
    timestamps: true,
    // When sending user data to the frontend (e.g. `res.json(user)`), this automatically scrubs sensitive fields
    toJSON: {
      transform(_doc, ret) {
        delete ret.password; // Never send password hash
        delete ret.refreshToken; // Never send refresh token
        delete ret.__v; // Hide MongoDB internal version number
        return ret;
      },
    },
  }
);

// ==========================================
// MIDDLEWARE: HASH PASSWORD BEFORE SAVING
// Right before saving a user to the database, check if the password is new or changed.
// If it is, run it through the bcrypt scrambler (cost factor 12) so it's unreadable in the database.
// ==========================================
userSchema.pre('save', async function () {
  if (!this.isModified('password')) return;
  this.password = await bcrypt.hash(this.password, 12);
});

// ==========================================
// HELPER: COMPARE PASSWORD
// When a user logs in, we can't un-scramble the database password. 
// Instead, we scramble the password they just typed in and see if the two scrambles match.
// ==========================================
userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

const User = mongoose.model('User', userSchema);

export default User;

import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';


const userSchema = new mongoose.Schema(
  {
    code: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    
    name: {
      type: String,
      required: [true, 'Name is required'],
      trim: true,
      maxlength: 100,
    },
    email: {
      type: String,
      required: [true, 'Email is required'],
      unique: true, 
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, 'Invalid email format'], // Regex to ensure it looks like an email
    },
    
    
    password: {
      type: String,
      required: [true, 'Password is required'],
      minlength: 8,
      select: false, 
    },
    
    role: {
      type: String,
      enum: ['admin', 'manager', 'staff'],
      default: 'staff',
    },
    
    isActive: {
      type: Boolean,
      default: true,
    },
    
    employeeId: { type: String, trim: true }, 
    dateOfBirth: { type: String },
    gender: { type: String },
    nicPassport: { type: String, trim: true }, 
    address: { type: String },
    city: { type: String },
    district: { type: String },
    postalCode: { type: String },
    
    joinDate: { type: String },
    employmentType: {
      type: String,
      enum: ['Full Time', 'Part Time', 'Contract'],
      default: 'Full Time',
    },
    
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
    },
    
    emergencyName: { type: String },
    emergencyRelationship: { type: String },
    emergencyPhone: { type: String },
    
   
    profileImage: { type: String, default: '' },
    
    status: {
      type: String,
      enum: ['Active', 'Inactive', 'Suspended'],
      default: 'Active',
    },
    lastLogin: { type: Date },
    
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
    toJSON: {
      transform(_doc, ret) {
        delete ret.password; 
        delete ret.refreshToken; 
        delete ret.__v; 
        return ret;
      },
    },
  }
);

// Right before saving a user to the database, check if the password is new or changed.
userSchema.pre('save', async function () {
  if (!this.isModified('password')) return;
  this.password = await bcrypt.hash(this.password, 12);
});


// HELPER: COMPARE PASSWORD
// When a user logs in, we can't un-scramble the database password. 
// Instead, we scramble the password they just typed in and see if the two scrambles match.

userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.password);
};

const User = mongoose.model('User', userSchema);

export default User;

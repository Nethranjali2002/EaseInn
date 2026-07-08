import User from '../models/user.model.js'; // The database model representing a staff member or admin
import Booking from '../models/booking.model.js'; // Database model for reservations
import Task from '../models/task.model.js'; // Database model for housekeeping/maintenance duties
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP errors
import { generateUserCode } from '../utils/codeGenerator.js'; // Helper that makes a random string like "EMP-9A1C"

export const getProfile = async (userId) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);
  return user;
};

const ALLOWED_PROFILE_FIELDS = ['name', 'phone', 'address', 'city', 'district', 'postalCode', 'dateOfBirth', 'gender', 'emergencyName', 'emergencyRelationship', 'emergencyPhone', 'profileImage'];


export const updateProfile = async (userId, updates) => {
  const sanitized = {};
  
  for (const key of ALLOWED_PROFILE_FIELDS) {
    if (updates[key] !== undefined) sanitized[key] = updates[key];
  }

  if (Object.keys(sanitized).length === 0) {
    throw new AppError('No valid fields to update', 400);
  }

  const user = await User.findByIdAndUpdate(userId, sanitized, {
    new: true,
    runValidators: true, 
  });

  if (!user) throw new AppError('User not found', 404);
  return user;
};


export const deleteAccount = async (userId) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  if (user.role === 'admin') {
    const adminCount = await User.countDocuments({ role: 'admin', isActive: true });
    if (adminCount <= 1) {
      throw new AppError('Cannot delete the last active admin account', 409);
    }
  }

  const activeBookings = await Booking.countDocuments({
    $or: [
      { createdBy: userId, bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] } },
    ],
  });
  if (activeBookings > 0) {
    throw new AppError('Cannot delete account with active bookings. Transfer or complete them first.', 409);
  }

  const activeTasks = await Task.countDocuments({
    assignedTo: userId,
    status: { $in: ['open', 'in-progress'] },
  });
  if (activeTasks > 0) {
    throw new AppError('Cannot delete account with assigned tasks. Reassign or complete them first.', 409);
  }

  await User.findByIdAndDelete(userId);
};

export const getAllUsers = async ({ page = 1, limit = 20, search = '', role }) => {
  const query = {};
  
  if (search) {
    query.$or = [
      { name: { $regex: search, $options: 'i' } },
      { email: { $regex: search, $options: 'i' } },
    ];
  }
  
  if (role) query.role = role;

  const total = await User.countDocuments(query);
  
  const users = await User.find(query)
    .select('-password -refreshToken') // SECURITY: Never ever send the hashed password or tokens to the frontend
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
    
  return { users, total, page, limit };
};


export const getUserById = async (userId) => {
  const user = await User.findById(userId).select('-password -refreshToken');
  if (!user) throw new AppError('User not found', 404);
  return user;
};


export const updateUserRole = async (userId, role, currentUserId) => {
  if (userId === currentUserId) {
    throw new AppError('Cannot change your own role', 409);
  }

  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  if (user.role === 'admin') {
    const adminCount = await User.countDocuments({ role: 'admin', isActive: true });
    if (adminCount <= 1) {
      throw new AppError('Cannot demote the last active admin', 409);
    }
  }

  user.role = role;
  await user.save();
  return user;
};

// Suspends or reactivates an employee without deleting them
export const toggleUserStatus = async (userId, isActive, currentUserId) => {
  if (userId === currentUserId) {
    throw new AppError('Cannot change your own status', 409);
  }

  const user = await User.findByIdAndUpdate(userId, { isActive }, { new: true });
  if (!user) throw new AppError('User not found', 404);

  if (!isActive && user.role === 'admin') {
    const adminCount = await User.countDocuments({ role: 'admin', isActive: true });
    if (adminCount < 1) {
      await User.findByIdAndUpdate(userId, { isActive: true });
      throw new AppError('Cannot deactivate the last active admin', 409);
    }
  }

  return user;
};

export const createUser = async (data) => {
  const existingUser = await User.findOne({ email: data.email });
  if (existingUser) throw new AppError('Email already in use', 400);

  if (!data.password || data.password.length < 8) {
    throw new AppError('Password must be at least 8 characters', 400);
  }

  const user = await User.create({ ...data, code: await generateUserCode() });
  return user;
};

const ALLOWED_ADMIN_UPDATE_FIELDS = ['name', 'email', 'role', 'phone', 'address', 'city', 'district', 'postalCode', 'employeeId', 'dateOfBirth', 'gender', 'nicPassport', 'employmentType', 'property', 'emergencyName', 'emergencyRelationship', 'emergencyPhone', 'isActive', 'status', 'profileImage'];

export const updateUser = async (userId, updates) => {
  const sanitized = {};
  
  for (const key of ALLOWED_ADMIN_UPDATE_FIELDS) {
    if (updates[key] !== undefined) sanitized[key] = updates[key];
  }

  if (Object.keys(sanitized).length === 0) {
    throw new AppError('No valid fields to update', 400);
  }

  const user = await User.findByIdAndUpdate(userId, sanitized, {
    new: true,
    runValidators: true,
  });
  
  if (!user) throw new AppError('User not found', 404);
  return user;
};

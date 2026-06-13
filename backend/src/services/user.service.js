import User from '../models/user.model.js'; // The database model representing a staff member or admin
import Booking from '../models/booking.model.js'; // Database model for reservations
import Task from '../models/task.model.js'; // Database model for housekeeping/maintenance duties
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP errors
import { generateUserCode } from '../utils/codeGenerator.js'; // Helper that makes a random string like "EMP-9A1C"

// ==========================================
// 1. GET PROFILE
// Fetches the logged-in user's own data
// ==========================================
export const getProfile = async (userId) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);
  return user;
};

// Security whitelist: Users can ONLY update these specific fields themselves.
// Notice that 'role' (admin/staff) and 'isActive' are missing. Only Admins can change those.
const ALLOWED_PROFILE_FIELDS = ['name', 'phone', 'address', 'city', 'district', 'postalCode', 'dateOfBirth', 'gender', 'emergencyName', 'emergencyRelationship', 'emergencyPhone', 'profileImage'];

// ==========================================
// 2. UPDATE PROFILE
// Allows a user to edit their own settings
// ==========================================
export const updateProfile = async (userId, updates) => {
  const sanitized = {};
  
  // Loop through the whitelist. If the user tried to send us a field (like 'role: admin'), it gets completely ignored.
  for (const key of ALLOWED_PROFILE_FIELDS) {
    if (updates[key] !== undefined) sanitized[key] = updates[key];
  }

  if (Object.keys(sanitized).length === 0) {
    throw new AppError('No valid fields to update', 400);
  }

  const user = await User.findByIdAndUpdate(userId, sanitized, {
    new: true, // Return the updated document, not the old one
    runValidators: true, // Make sure they didn't bypass Mongoose string length/type checks
  });

  if (!user) throw new AppError('User not found', 404);
  return user;
};

// ==========================================
// 3. DELETE ACCOUNT
// Highly restricted deletion logic
// ==========================================
export const deleteAccount = async (userId) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  // SECURITY: Prevent the system from "bricking" itself. 
  // If this person is the VERY LAST admin in the entire database, refuse to delete them.
  if (user.role === 'admin') {
    const adminCount = await User.countDocuments({ role: 'admin', isActive: true });
    if (adminCount <= 1) {
      throw new AppError('Cannot delete the last active admin account', 409);
    }
  }

  // Prevent data corruption: A staff member cannot be deleted if they are currently assigned to active reservations
  const activeBookings = await Booking.countDocuments({
    $or: [
      { createdBy: userId, bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] } },
    ],
  });
  if (activeBookings > 0) {
    throw new AppError('Cannot delete account with active bookings. Transfer or complete them first.', 409);
  }

  // Prevent workflow blockage: A staff member cannot be deleted if they still have uncompleted chores
  const activeTasks = await Task.countDocuments({
    assignedTo: userId,
    status: { $in: ['open', 'in-progress'] },
  });
  if (activeTasks > 0) {
    throw new AppError('Cannot delete account with assigned tasks. Reassign or complete them first.', 409);
  }

  // If all checks pass, actually delete the user
  await User.findByIdAndDelete(userId);
};

// ==========================================
// 4. GET ALL USERS (ADMIN ONLY)
// Fetches the employee directory
// ==========================================
export const getAllUsers = async ({ page = 1, limit = 20, search = '', role }) => {
  const query = {};
  
  // Allow searching by name or email
  if (search) {
    query.$or = [
      { name: { $regex: search, $options: 'i' } },
      { email: { $regex: search, $options: 'i' } },
    ];
  }
  
  // Filter by role (e.g. show me only "cleaners" or "managers")
  if (role) query.role = role;

  const total = await User.countDocuments(query);
  
  const users = await User.find(query)
    .select('-password -refreshToken') // SECURITY: Never ever send the hashed password or tokens to the frontend
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
    
  return { users, total, page, limit };
};

// ==========================================
// 5. GET USER BY ID (ADMIN ONLY)
// ==========================================
export const getUserById = async (userId) => {
  const user = await User.findById(userId).select('-password -refreshToken');
  if (!user) throw new AppError('User not found', 404);
  return user;
};

// ==========================================
// 6. UPDATE USER ROLE (ADMIN ONLY)
// Promotes or demotes an employee
// ==========================================
export const updateUserRole = async (userId, role, currentUserId) => {
  // Security: An admin cannot accidentally demote themselves, which could lock them out of the system
  if (userId === currentUserId) {
    throw new AppError('Cannot change your own role', 409);
  }

  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);

  // Security: If we are demoting an Admin to Staff, make sure they aren't the last Admin alive
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

// ==========================================
// 7. TOGGLE USER STATUS (ADMIN ONLY)
// Suspends or reactivates an employee without deleting them
// ==========================================
export const toggleUserStatus = async (userId, isActive, currentUserId) => {
  // Security: Admins cannot suspend themselves
  if (userId === currentUserId) {
    throw new AppError('Cannot change your own status', 409);
  }

  const user = await User.findByIdAndUpdate(userId, { isActive }, { new: true });
  if (!user) throw new AppError('User not found', 404);

  // Security: Don't let someone suspend the last remaining Admin
  if (!isActive && user.role === 'admin') {
    const adminCount = await User.countDocuments({ role: 'admin', isActive: true });
    if (adminCount < 1) {
      // Revert the change immediately
      await User.findByIdAndUpdate(userId, { isActive: true });
      throw new AppError('Cannot deactivate the last active admin', 409);
    }
  }

  return user;
};

// ==========================================
// 8. CREATE USER (ADMIN ONLY)
// Manually add a new staff member to the system
// ==========================================
export const createUser = async (data) => {
  // Check for duplicates
  const existingUser = await User.findOne({ email: data.email });
  if (existingUser) throw new AppError('Email already in use', 400);

  if (!data.password || data.password.length < 8) {
    throw new AppError('Password must be at least 8 characters', 400);
  }

  // Create the employee and generate their unique EMP-XXXX ID badge number
  const user = await User.create({ ...data, code: await generateUserCode() });
  return user;
};

// The much larger whitelist available only to Admins.
// They can change almost everything about an employee, including which property they work at.
const ALLOWED_ADMIN_UPDATE_FIELDS = ['name', 'email', 'role', 'phone', 'address', 'city', 'district', 'postalCode', 'employeeId', 'dateOfBirth', 'gender', 'nicPassport', 'employmentType', 'property', 'emergencyName', 'emergencyRelationship', 'emergencyPhone', 'isActive', 'status', 'profileImage'];

// ==========================================
// 9. UPDATE USER (ADMIN ONLY)
// ==========================================
export const updateUser = async (userId, updates) => {
  const sanitized = {};
  
  // Enforce the Admin whitelist
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

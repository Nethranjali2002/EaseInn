import User from '../models/user.model.js';
import { AppError } from '../middlewares/error.middleware.js';

export const getProfile = async (userId) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);
  return user;
};

export const updateProfile = async (userId, updates) => {
  const allowedFields = ['name'];
  const sanitized = {};

  for (const key of allowedFields) {
    if (updates[key] !== undefined) sanitized[key] = updates[key];
  }

  const user = await User.findByIdAndUpdate(userId, sanitized, {
    new: true,
    runValidators: true,
  });

  if (!user) throw new AppError('User not found', 404);
  return user;
};

export const deleteAccount = async (userId) => {
  const user = await User.findByIdAndDelete(userId);
  if (!user) throw new AppError('User not found', 404);
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
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
  return { users, total, page, limit };
};

export const getUserById = async (userId) => {
  const user = await User.findById(userId);
  if (!user) throw new AppError('User not found', 404);
  return user;
};

export const updateUserRole = async (userId, role) => {
  const user = await User.findByIdAndUpdate(userId, { role }, { new: true, runValidators: true });
  if (!user) throw new AppError('User not found', 404);
  return user;
};

export const toggleUserStatus = async (userId, isActive) => {
  const user = await User.findByIdAndUpdate(userId, { isActive }, { new: true });
  if (!user) throw new AppError('User not found', 404);
  return user;
};

export const createUser = async (data) => {
  const existingUser = await User.findOne({ email: data.email });
  if (existingUser) throw new AppError('Email already in use', 400);
  const user = await User.create(data);
  return user;
};

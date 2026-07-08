import Joi from 'joi';
// AUTHENTICATION & USER VALIDATORS
export const registerSchema = Joi.object({
  name: Joi.string().trim().max(100).required(),
  email: Joi.string().email().lowercase().trim().required(),
  password: Joi.string().min(8).max(128).required(),
});

export const loginSchema = Joi.object({
  email: Joi.string().email().lowercase().trim().required(),
  password: Joi.string().required(),
});

export const refreshSchema = Joi.object({
  refreshToken: Joi.string().required(),
});

export const updateProfileSchema = Joi.object({
  name: Joi.string().trim().max(100).optional(),
  profileImage: Joi.string().optional().allow(''),
}).min(1); // Ensures they actually sent AT LEAST ONE field to update

export const forgotPasswordSchema = Joi.object({
  email: Joi.string().email().lowercase().trim().required(),
});

export const resetPasswordSchema = Joi.object({
  token: Joi.string().required(),
  password: Joi.string().min(8).max(128).required(),
});

export const changePasswordSchema = Joi.object({
  currentPassword: Joi.string().required(),
  newPassword: Joi.string().min(8).max(128).required(),
});


// ADMIN/HR: STAFF CREATION

export const createUserSchema = Joi.object({
  name: Joi.string().trim().max(100).required(),
  email: Joi.string().email().lowercase().trim().required(),
  password: Joi.string().min(8).max(128).required(),
  role: Joi.string().valid('admin', 'manager', 'staff').optional(),
  phone: Joi.string().trim().pattern(/^\+?\d{10}$/).messages({ 'string.pattern.base': 'Invalid phone number' }).optional(),
  address: Joi.string().optional(),
  city: Joi.string().optional(),
  district: Joi.string().optional(),
  postalCode: Joi.string().optional(),
  employeeId: Joi.string().trim().optional(),
  dateOfBirth: Joi.string().optional(),
  gender: Joi.string().optional(),
  nicPassport: Joi.string().trim().optional(),
  employmentType: Joi.string().valid('Full Time', 'Part Time', 'Contract').optional(),
  // Ensure the Property ID is a valid 24-character MongoDB ObjectId
  property: Joi.string().hex().length(24).optional(),
  emergencyName: Joi.string().optional(),
  emergencyRelationship: Joi.string().optional(),
  emergencyPhone: Joi.string().optional(),
  profileImage: Joi.string().optional().allow(''),
});

export const updateUserSchema = Joi.object({
  name: Joi.string().trim().max(100).optional(),
  email: Joi.string().email().lowercase().trim().optional(),
  role: Joi.string().valid('admin', 'manager', 'staff').optional(),
  phone: Joi.string().trim().pattern(/^\+?\d{10}$/).messages({ 'string.pattern.base': 'Invalid phone number' }).optional(),
  address: Joi.string().optional(),
  city: Joi.string().optional(),
  district: Joi.string().optional(),
  postalCode: Joi.string().optional(),
  employeeId: Joi.string().trim().optional(),
  dateOfBirth: Joi.string().optional(),
  gender: Joi.string().optional(),
  nicPassport: Joi.string().trim().optional(),
  employmentType: Joi.string().valid('Full Time', 'Part Time', 'Contract').optional(),
  property: Joi.string().hex().length(24).optional().allow(null),
  emergencyName: Joi.string().optional(),
  emergencyRelationship: Joi.string().optional(),
  emergencyPhone: Joi.string().optional(),
  profileImage: Joi.string().optional().allow(''),
  isActive: Joi.boolean().optional(),
  status: Joi.string().valid('Active', 'Inactive', 'Suspended').optional(),
}).min(1);

export const updateUserRoleSchema = Joi.object({
  role: Joi.string().valid('admin', 'manager', 'staff').required(),
});

export const toggleUserStatusSchema = Joi.object({
  isActive: Joi.boolean().required(),
});

import * as userService from '../services/user.service.js';
import { sendSuccess } from '../utils/response.util.js';
import { logAudit } from '../utils/audit.util.js';

export const getProfile = async (req, res, next) => {
  try {
    const user = await userService.getProfile(req.user.sub);
    return sendSuccess(res, { data: { user } });
  } catch (err) {
    return next(err);
  }
};

export const updateProfile = async (req, res, next) => {
  try {
    const user = await userService.updateProfile(req.user.sub, req.body);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'User', entityId: req.user.sub, changes: req.body, description: 'Profile updated', ip: req.ip, userAgent: req.get('user-agent') });
    return sendSuccess(res, {
      message: 'Profile updated',
      data: { user },
    });
  } catch (err) {
    return next(err);
  }
};

export const deleteAccount = async (req, res, next) => {
  try {
    await userService.deleteAccount(req.user.sub);
    await logAudit({ user: req.user.sub, action: 'delete', entity: 'User', entityId: req.user.sub, description: 'Account deleted', ip: req.ip, userAgent: req.get('user-agent') });
    return sendSuccess(res, { message: 'Account deleted' });
  } catch (err) {
    return next(err);
  }
};

export const getAllUsers = async (req, res, next) => {
  try {
    const { page, limit, search, role } = req.query;
    const result = await userService.getAllUsers({ page: parseInt(page) || 1, limit: parseInt(limit) || 20, search, role });
    return sendSuccess(res, { data: result });
  } catch (err) {
    return next(err);
  }
};

export const getUserById = async (req, res, next) => {
  try {
    const user = await userService.getUserById(req.params.id);
    return sendSuccess(res, { data: { user } });
  } catch (err) {
    return next(err);
  }
};

export const updateUserRole = async (req, res, next) => {
  try {
    const user = await userService.updateUserRole(req.params.id, req.body.role);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'User', entityId: req.params.id, changes: { role: req.body.role }, description: 'User role updated', ip: req.ip, userAgent: req.get('user-agent') });
    return sendSuccess(res, { message: 'Role updated', data: { user } });
  } catch (err) {
    return next(err);
  }
};

export const toggleUserStatus = async (req, res, next) => {
  try {
    const user = await userService.toggleUserStatus(req.params.id, req.body.isActive);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'User', entityId: req.params.id, changes: { isActive: req.body.isActive }, description: 'User status toggled', ip: req.ip, userAgent: req.get('user-agent') });
    return sendSuccess(res, { message: 'Status updated', data: { user } });
  } catch (err) {
    return next(err);
  }
};

export const createUser = async (req, res, next) => {
  try {
    const user = await userService.createUser(req.body);
    await logAudit({ user: req.user.sub, action: 'create', entity: 'User', entityId: user._id, description: `Created user ${user.email} with role ${user.role}`, ip: req.ip, userAgent: req.get('user-agent') });
    return sendSuccess(res, { message: 'User created successfully', data: { user } });
  } catch (err) {
    return next(err);
  }
};

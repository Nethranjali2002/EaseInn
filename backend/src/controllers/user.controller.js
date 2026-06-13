import * as userService from '../services/user.service.js'; // Imports the Brain handling all User/Account logic
import { sendSuccess } from '../utils/response.util.js'; // Helper for formatting success responses
import { logAudit } from '../utils/audit.util.js'; // Helper for recording actions securely


// ==========================================
// 1. GET PROFILE (My Account)
// ==========================================
export const getProfile = async (req, res, next) => {
  try {
    // Pass the currently logged in user's ID to fetch their full profile details
    const user = await userService.getProfile(req.user.sub);
    return sendSuccess(res, { data: { user } });
  } catch (err) {
    return next(err);
  }
};


// ==========================================
// 2. UPDATE PROFILE
// ==========================================
export const updateProfile = async (req, res, next) => {
  try {
    // Pass their ID and the new profile data (e.g., new phone number) to the Service
    const user = await userService.updateProfile(req.user.sub, req.body);
    
    // Log that this specific user updated their own profile
    await logAudit({ user: req.user.sub, action: 'update', entity: 'User', entityId: req.user.sub, changes: req.body, description: 'Profile updated', ip: req.ip, userAgent: req.get('user-agent') });
    
    return sendSuccess(res, {
      message: 'Profile updated',
      data: { user },
    });
  } catch (err) {
    return next(err);
  }
};


// ==========================================
// 3. DELETE ACCOUNT
// ==========================================
export const deleteAccount = async (req, res, next) => {
  try {
    // Permanently erases the currently logged-in user's account
    await userService.deleteAccount(req.user.sub);
    
    // Log the account deletion
    await logAudit({ user: req.user.sub, action: 'delete', entity: 'User', entityId: req.user.sub, description: 'Account deleted', ip: req.ip, userAgent: req.get('user-agent') });
    
    return sendSuccess(res, { message: 'Account deleted' });
  } catch (err) {
    return next(err);
  }
};


// ==========================================
// 4. GET ALL USERS (Admin/Manager Dashboard)
// ==========================================
export const getAllUsers = async (req, res, next) => {
  try {
    // Extract pagination and filters (like searching for 'staff' role only)
    const { page, limit, search, role } = req.query;
    
    // Fetch the filtered list of all users registered in the system
    const result = await userService.getAllUsers({ page: parseInt(page) || 1, limit: parseInt(limit) || 20, search, role });
    
    return sendSuccess(res, { data: result });
  } catch (err) {
    return next(err);
  }
};


// ==========================================
// 5. GET USER BY ID
// ==========================================
export const getUserById = async (req, res, next) => {
  try {
    // Fetches the exact details of a specific user (usually used by Admins to view an employee's profile)
    const user = await userService.getUserById(req.params.id);
    return sendSuccess(res, { data: { user } });
  } catch (err) {
    return next(err);
  }
};


// ==========================================
// 6. UPDATE USER ROLE (Admin Only)
// ==========================================
export const updateUserRole = async (req, res, next) => {
  try {
    // Allows an Admin to promote a 'staff' member to 'manager', or demote them
    const user = await userService.updateUserRole(req.params.id, req.body.role, req.user.sub);
    
    // Crucial security log: records exactly who promoted/demoted this person
    await logAudit({ user: req.user.sub, action: 'update', entity: 'User', entityId: req.params.id, changes: { role: req.body.role }, description: 'User role updated', ip: req.ip, userAgent: req.get('user-agent') });
    
    return sendSuccess(res, { message: 'Role updated', data: { user } });
  } catch (err) {
    return next(err);
  }
};


// ==========================================
// 7. TOGGLE USER STATUS (Admin Only)
// ==========================================
export const toggleUserStatus = async (req, res, next) => {
  try {
    // Allows an Admin to suspend or activate a user account instantly
    const user = await userService.toggleUserStatus(req.params.id, req.body.isActive, req.user.sub);
    
    // Log the suspension/activation
    await logAudit({ user: req.user.sub, action: 'update', entity: 'User', entityId: req.params.id, changes: { isActive: req.body.isActive }, description: 'User status toggled', ip: req.ip, userAgent: req.get('user-agent') });
    
    return sendSuccess(res, { message: 'Status updated', data: { user } });
  } catch (err) {
    return next(err);
  }
};


// ==========================================
// 8. CREATE USER (Admin Registration)
// ==========================================
export const createUser = async (req, res, next) => {
  try {
    // Allows an Admin to manually create a new staff account from the dashboard
    const user = await userService.createUser(req.body);
    
    // Log the manual creation
    await logAudit({ user: req.user.sub, action: 'create', entity: 'User', entityId: user._id, description: `Created user ${user.email} with role ${user.role}`, ip: req.ip, userAgent: req.get('user-agent') });
    
    return sendSuccess(res, { message: 'User created successfully', data: { user } });
  } catch (err) {
    return next(err);
  }
};


// ==========================================
// 9. UPDATE USER (Admin Editing Employee Data)
// ==========================================
export const updateUser = async (req, res, next) => {
  try {
    // Allows an Admin to edit another user's profile details
    const user = await userService.updateUser(req.params.id, req.body);
    
    // Log the update
    await logAudit({ user: req.user.sub, action: 'update', entity: 'User', entityId: req.params.id, changes: req.body, description: `Updated user ${user.email} profile details`, ip: req.ip, userAgent: req.get('user-agent') });
    
    return sendSuccess(res, { message: 'User updated successfully', data: { user } });
  } catch (err) {
    return next(err);
  }
};

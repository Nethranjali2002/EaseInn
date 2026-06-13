import jwt from 'jsonwebtoken'; // Imports the library used to verify and decode JSON Web Tokens
import env from '../config/env.config.js'; // Imports our environment variables (like the secret key)
import { AppError } from './error.middleware.js'; // Imports our custom Error class to throw structured errors
import User from '../models/user.model.js'; // Imports the MongoDB User model to check the database

// ==========================================
// 1. JWT AUTHENTICATION
// Intercepts the request, extracts the Bearer token, verifies it,
// and ensures the user account is still active before proceeding.
// ==========================================
export const authenticate = async (req, _res, next) => {
  // Grab the 'Authorization' header from the incoming HTTP request
  const authHeader = req.headers.authorization;

  // Check if the header exists and if it starts with the word 'Bearer '
  if (!authHeader?.startsWith('Bearer ')) {
    // If not, instantly stop the request and send a 401 Unauthorized error
    return next(new AppError('Authentication required', 401));
  }

  // Split the string "Bearer <token_string>" and grab just the <token_string> part
  const token = authHeader.split(' ')[1];

  try {
    // Use the jwt library and our secret key to decrypt/verify the token
    const decoded = jwt.verify(token, env.jwt.secret);

    // Look up the user in MongoDB using the ID stored inside the decoded token (decoded.sub)
    // We only select the 'isActive', 'status', and 'role' fields to save memory
    const user = await User.findById(decoded.sub).select('isActive status role');
    
    // If MongoDB doesn't find the user (maybe they were deleted), throw an error
    if (!user) {
      return next(new AppError('User account no longer exists', 401));
    }
    
    // Check if the user's account has been deactivated or suspended by an admin
    if (user.isActive === false || user.status === 'Inactive' || user.status === 'Suspended') {
      return next(new AppError('Your account has been deactivated. Please contact an administrator.', 403));
    }

    // Attach the user's ID and role to the request object so the next functions can use it
    req.user = { sub: decoded.sub, role: user.role };
    
    // Call next() to allow the request to proceed to the controller
    return next();
  } catch (err) {
    // If it's a known AppError (like the deactivated account error), pass it along
    if (err instanceof AppError) return next(err);
    // Otherwise, the JWT verify failed (token is expired or fake), throw a generic 401 error
    return next(new AppError('Invalid or expired token', 401));
  }
};

// ==========================================
// 2. ROLE AUTHORIZATION
// Checks if the authenticated user has the required roles
// (e.g., 'admin' or 'manager') to access the requested route.
// ==========================================
export const authorize = (...roles) => (req, _res, next) => {
  // Check if the array of allowed roles (e.g., ['admin']) includes the role of the user trying to access it
  if (!roles.includes(req.user?.role)) {
    // If their role is not in the allowed list, block them with a 403 Forbidden error
    return next(new AppError('Insufficient permissions', 403));
  }
  // If their role is allowed, let them pass to the controller
  return next();
};

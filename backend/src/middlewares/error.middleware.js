import logger from '../utils/logger.util.js'; // Imports our Winston logger to safely write errors to a log file
import { sendError } from '../utils/response.util.js'; // Imports our standard JSON error response formatter

// ==========================================
// 1. GLOBAL ERROR HANDLER
// Catches all errors thrown across the application, normalizes them,
// logs them securely, and sends a consistent JSON response.
// ==========================================
const errorHandler = (err, req, res, _next) => {
  // Grab the HTTP status code from the error object, or default to 500 (Internal Server Error)
  let statusCode = err.statusCode || 500;
  // If the error is operational (a predictable error we threw intentionally), show its message. 
  // Otherwise, hide the raw code error from the user by showing "Internal Server Error"
  let message = err.isOperational ? err.message : 'Internal Server Error';
  // Grab any specific field errors (like an array of validation failures), default to null
  let errors = err.errors || null;

  // Intercept Mongoose CastErrors (e.g., someone sent a totally invalid MongoDB ID format)
  if (err.name === 'CastError') {
    // Change the status to 400 Bad Request
    statusCode = 400;
    // Tell the user exactly which field had the bad format
    message = `Invalid ${err.path}: ${err.value}`;
    errors = [{ field: err.path, message }];
  }

  // Intercept Mongoose ValidationErrors (e.g., trying to save a string to a number field)
  if (err.name === 'ValidationError') {
    statusCode = 400;
    message = 'Validation failed';
    // Loop through the Mongoose errors and map them into a clean array
    errors = Object.values(err.errors).map((e) => ({
      field: e.path,
      message: e.message,
    }));
  }

  // Intercept MongoDB Duplicate Key Errors (e.g., trying to register an email that already exists)
  if (err.code === 11000) {
    statusCode = 409; // 409 Conflict
    // Extract the exact field name that caused the duplicate error
    const field = Object.keys(err.keyValue)[0];
    message = `Duplicate value for ${field}`;
    errors = [{ field, message }];
  }

  // Securely log the raw error and the requested URL to our server console/files for debugging
  logger.error({
    err,
    method: req.method,
    url: req.originalUrl,
    statusCode,
  });

  // Finally, send the perfectly formatted JSON error back to the frontend
  return sendError(res, { statusCode, message, errors });
};

// ==========================================
// 2. CUSTOM APP ERROR CLASS
// Allows developers to throw clean, predictable errors inside Controllers/Services
// Example: throw new AppError('Room is already booked!', 400);
// ==========================================
export class AppError extends Error {
  constructor(message, statusCode = 500) {
    // Call the parent JavaScript Error class with the message
    super(message);
    // Attach the HTTP status code (e.g., 404, 400, 401)
    this.statusCode = statusCode;
    // Mark this error as 'operational' meaning we expected it and it's safe to show the user
    this.isOperational = true;
    // Capture the stack trace (the exact line of code where the error happened) for debugging
    Error.captureStackTrace(this, this.constructor);
  }
}

export default errorHandler; // Export the global handler to be used in app.js

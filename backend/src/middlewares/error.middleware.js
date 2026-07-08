import logger from '../utils/logger.util.js'; 
import { sendError } from '../utils/response.util.js'; 

// 1. GLOBAL ERROR HANDLER

const errorHandler = (err, req, res, _next) => {
  let statusCode = err.statusCode || 500;
  let message = err.isOperational ? err.message : 'Internal Server Error';
  let errors = err.errors || null;

  if (err.name === 'CastError') {
    statusCode = 400;
    message = `Invalid ${err.path}: ${err.value}`;
    errors = [{ field: err.path, message }];
  }

  if (err.name === 'ValidationError') {
    statusCode = 400;
    message = 'Validation failed';
    errors = Object.values(err.errors).map((e) => ({
      field: e.path,
      message: e.message,
    }));
  }

  if (err.code === 11000) {
    statusCode = 409; 
    const field = Object.keys(err.keyValue)[0];
    message = `Duplicate value for ${field}`;
    errors = [{ field, message }];
  }

  logger.error({
    err,
    method: req.method,
    url: req.originalUrl,
    statusCode,
  });

  return sendError(res, { statusCode, message, errors });
};

// 2. CUSTOM APP ERROR CLASS
export class AppError extends Error {
  constructor(message, statusCode = 500) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

export default errorHandler; 
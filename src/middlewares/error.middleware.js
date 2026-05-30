import logger from '../utils/logger.util.js';
import { sendError } from '../utils/response.util.js';

// eslint-disable-next-line no-unused-vars
const errorHandler = (err, req, res, _next) => {
  const statusCode = err.statusCode || 500;
  const message = err.isOperational ? err.message : 'Internal Server Error';

  logger.error({
    err,
    method: req.method,
    url: req.originalUrl,
    statusCode,
  });

  return sendError(res, { statusCode, message, errors: err.errors || null });
};

export class AppError extends Error {
  constructor(message, statusCode = 500) {
    super(message);
    this.statusCode = statusCode;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

export default errorHandler;

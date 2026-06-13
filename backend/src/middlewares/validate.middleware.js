import { AppError } from './error.middleware.js'; // Imports our custom error class

// ==========================================
// 1. DATA VALIDATION MIDDLEWARE
// Intercepts the request and checks the incoming data (req.body)
// against a predefined Joi schema.
// If the data is bad (e.g., missing an email), it instantly rejects
// the request with a clean 400 error.
// ==========================================
const validate = (schema) => (req, _res, next) => {
  // Use the Joi schema to validate the incoming JSON body (req.body)
  const { error, value } = schema.validate(req.body, {
    // Check ALL fields for errors instead of stopping at the very first error it finds
    abortEarly: false,
    // Automatically delete any random properties the user sent that aren't defined in our schema
    stripUnknown: true, 
  });

  // If Joi found validation errors (e.g., email is missing, password too short)
  if (error) {
    // Loop through the Joi errors and map them into a clean array of readable messages
    const details = error.details.map((detail) => ({
      // Grab the exact field that failed (e.g., 'password')
      field: detail.path.join('.'),
      // Grab the human-readable error message and remove the ugly quote marks
      message: detail.message.replace(/"/g, ''),
    }));
    
    // Create a new 400 Bad Request error
    const err = new AppError('Validation failed', 400);
    // Attach our clean array of specific field errors to the main error object
    err.errors = details;
    
    // Throw the error so the Global Error Handler catches it and sends it to the user
    return next(err);
  }

  // If validation passes, overwrite req.body with the perfectly sanitized 'value' object
  req.body = value;
  
  // Let the request continue to the controller!
  return next();
};

export default validate; // Export the function so it can be used in routes/index.js

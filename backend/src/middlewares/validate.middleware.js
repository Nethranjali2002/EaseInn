import { AppError } from './error.middleware.js'; 

// 1. DATA VALIDATION MIDDLEWARE

const validate = (schema) => (req, _res, next) => {
  const { error, value } = schema.validate(req.body, {
    abortEarly: false,
    stripUnknown: true, 
  });

  if (error) {
    const details = error.details.map((detail) => ({
      field: detail.path.join('.'),
      message: detail.message.replace(/"/g, ''),
    }));
    
    const err = new AppError('Validation failed', 400);
    err.errors = details;
    
    return next(err);
  }

  req.body = value;
  
  return next();
};

export default validate; 

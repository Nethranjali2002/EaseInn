// ==========================================
// 1. SEND SUCCESS
// A standardized helper function used by every single controller in the backend.
// This ensures that all successful API responses look exactly the same to the frontend React code.
// Format: { success: true, message: "...", data: { ... } }
// ==========================================
export const sendSuccess = (res, { statusCode = 200, message = 'Success', data = null } = {}) => {
  return res.status(statusCode).json({
    success: true,
    message,
    data,
  });
};


// ==========================================
// 2. SEND ERROR
// The exact opposite of sendSuccess. Ensures the frontend always receives errors in a predictable format.
// Helps the frontend easily display toast notifications or red error text under form fields.
// Format: { success: false, message: "...", errors: { email: "Invalid" } }
// ==========================================
export const sendError = (res, { statusCode = 500, message = 'Internal Server Error', errors = null } = {}) => {
  return res.status(statusCode).json({
    success: false,
    message,
    ...(errors && { errors }), // Only include the 'errors' object if there are actual detailed validation errors
  });
};

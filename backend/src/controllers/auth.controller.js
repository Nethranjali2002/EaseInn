import * as authService from '../services/auth.service.js'; // Imports the "Brain" that does the heavy lifting for passwords and tokens
import { sendSuccess } from '../utils/response.util.js'; // Imports our custom helper that formats JSON success messages perfectly
import { logAudit } from '../utils/audit.util.js'; // Imports our spy tool that silently records every action into the database


// 1. REGISTER NEW USER


export const register = async (req, res, next) => {
  try {
    // Call the Service layer with the JSON body (email, password, etc.)
    // It returns the new user object along with their shiny new JWT tokens
    const { user, accessToken, refreshToken } = await authService.register(req.body);
    
    // Silently log this event to our Audit database so admins can track who joined and from what IP address
    await logAudit({ user: user._id, action: 'register', entity: 'User', entityId: user._id, description: `New user registered: ${user.email}`, ip: req.ip, userAgent: req.get('user-agent') });
    
    // Send a beautiful 201 Created JSON response back to the frontend
    return sendSuccess(res, {
      statusCode: 201, // 201 means "Created successfully"
      message: 'Registration successful',
      data: { user, accessToken, refreshToken },
    });
  } catch (err) {
    // If the Service crashed (e.g. email already exists), push the error to the Global Error Handler
    return next(err);
  }
};

// ==========================================
// 2. USER LOGIN
// Takes an email and password, checks if they match,
// and if so, generates fresh JWT tokens.
// ==========================================
export const login = async (req, res, next) => {
  try {
    
    // Ask the Service layer to check the email and password combination
    // If they match, it gives us the user profile and tokens back
    const { user, accessToken, refreshToken } = await authService.login(req.body);
    
    // Send a 200 OK success message back to the frontend with the tokens
    return sendSuccess(res, {
      message: 'Login successful',
      data: { user, accessToken, refreshToken },
    });
  } catch (err) {
    // If the password was wrong, the Service will throw an error, and we catch it here
    return next(err);
  }
};

// ==========================================
// 3. REFRESH TOKEN
// Access tokens expire quickly (e.g., 15 minutes) for security.
// The frontend uses this route to trade a valid Refresh Token for a new Access Token.
// ==========================================
export const refresh = async (req, res, next) => {
  try {
    // Grab the refresh token that the frontend sent in the request body
    const { refreshToken } = req.body;
    
    // Ask the Service layer to verify the refresh token and generate a fresh pair of tokens
    const tokens = await authService.refreshAccessToken(refreshToken);
    
    // Send the new tokens back to the frontend so the user stays logged in without typing their password again
    return sendSuccess(res, {
      message: 'Token refreshed',
      data: tokens,
    });
  } catch (err) {
    // If the refresh token is fake or expired, catch the error and send it to the frontend
    return next(err);
  }
};

// ==========================================
// 4. USER LOGOUT
// Deletes the user's tokens from the server so they can no longer make authenticated requests.
// ==========================================
export const logout = async (req, res, next) => {
  try {
    // Ask the Service layer to destroy all tokens associated with this specific user's ID
    await authService.logout(req.user.sub);
    
    // Log the logout action in the Audit log so admins know exactly when the staff member left the system
    await logAudit({ user: req.user.sub, action: 'logout', entity: 'User', entityId: req.user.sub, description: 'User logged out', ip: req.ip, userAgent: req.get('user-agent') });
    
    // Tell the frontend that the logout was fully successful
    return sendSuccess(res, { message: 'Logged out successfully' });
  } catch (err) {
    return next(err);
  }
};

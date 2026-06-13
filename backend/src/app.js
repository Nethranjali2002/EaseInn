import express from 'express'; // The core framework that runs our web server
import cookieParser from 'cookie-parser'; // Utility to read and parse cookies from incoming requests
import path from 'path'; // Node.js built-in module for working with file and directory paths
import { fileURLToPath } from 'url'; // Required to replicate __dirname behavior in ES modules
import { helmetMiddleware, corsMiddleware, rateLimiter } from './middlewares/security.middleware.js'; // Security middlewares to protect our server
import errorHandler from './middlewares/error.middleware.js'; // Our custom global error handler
import routes from './routes/index.js'; // Imports all our API endpoints
import { setupSwagger } from './config/swagger.js'; // Imports our API documentation setup

// Calculate the directory name for ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Initialize the Express application
const app = express();

// ==========================================
// 1. GLOBAL MIDDLEWARES (Security & Parsing)
// These run on EVERY single incoming request before hitting our routes.
// ==========================================

// Adds security headers to prevent common vulnerabilities (like Cross-Site Scripting)
app.use(helmetMiddleware);

// Allows our frontend (React app) to communicate with this backend without browser CORS errors
app.use(corsMiddleware);

// Protects the server from brute-force and DDoS attacks by limiting requests per IP
app.use(rateLimiter);

// Parses incoming JSON data in the request body, but strictly limits it to 10kb to prevent memory crashes
app.use(express.json({ limit: '10kb' }));

// Parses URL-encoded data (like form submissions)
app.use(express.urlencoded({ extended: false }));

// Parses cookie headers and populates req.cookies
app.use(cookieParser());

// ==========================================
// 2. DOCUMENTATION & STATIC FILES
// ==========================================

// Configures and mounts the Swagger UI documentation at /api-docs
setupSwagger(app);

// Serves static HTML files for the public-facing guest review page (if applicable)
app.use('/guest', express.static(path.join(__dirname, '../web')));

// ==========================================
// 3. API ROUTES
// ==========================================

// Mounts all our backend routes under the '/api/v1' prefix
app.use('/api/v1', routes);

// ==========================================
// 4. FALLBACK & ERROR HANDLING
// ==========================================

// Catch-all route handler for requests that don't match any of our defined endpoints
app.use((_req, res) => {
  res.status(404).json({ success: false, message: 'Route not found' });
});

// The Global Error Handler. If any route or service throws an error, it ends up here
// to be beautifully formatted and logged before sending a response to the user.
app.use(errorHandler);

// Export the configured express app without starting the server (useful for testing)
export default app;

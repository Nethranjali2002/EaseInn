// This automatically reads the hidden `.env` file in our project root and loads those variables into `process.env`
import 'dotenv/config';

// ==========================================
// ENVIRONMENT CONFIGURATION MANAGER
// Instead of typing `process.env.SOME_VARIABLE` everywhere in our code, we centralize it here.
// This gives us three huge benefits:
// 1. Fallback Values: If we forget to put RATE_LIMIT_MAX in the .env file, it automatically defaults to 100.
// 2. Type Casting: .env files only store strings. Here we use `parseInt()` to convert strings into actual Numbers.
// 3. Organization: All our secret keys and configs are grouped logically (e.g., env.jwt.secret instead of process.env.JWT_SECRET).
// ==========================================

const env = {
  // Is the app running on a developer's laptop ('development') or on a live server ('production')?
  nodeEnv: process.env.NODE_ENV || 'development',
  
  // The port the Express server will listen on
  port: parseInt(process.env.PORT, 10) || 3000,
  
  // The connection string for the MongoDB database
  mongoUri: process.env.MONGO_URI || 'mongodb://localhost:27017/easeinn',
  
  // ==========================================
  // SECURITY & AUTHENTICATION
  // ==========================================
  jwt: {
    secret: process.env.JWT_SECRET, // The master key used to scramble user tokens (CRITICAL)
    expiresIn: process.env.JWT_EXPIRES_IN || '15m', // Short-lived access token for security
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d', // Long-lived token to keep users logged in
  },
  cors: {
    origin: process.env.CORS_ORIGIN || '*', // Which frontend websites are allowed to talk to this API?
  },
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 900000, // 15 minutes in milliseconds
    max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 100, // Max 100 requests per IP every 15 minutes
  },
  
  // ==========================================
  // LOGGING & URLS
  // ==========================================
  logLevel: process.env.LOG_LEVEL || 'info',
  frontendUrl: process.env.FRONTEND_URL || 'http://localhost:3000', // Used to build clickable links in emails
  appUrl: process.env.APP_URL || 'http://localhost:5000', // The backend's own URL (used for webhooks)
  
  // ==========================================
  // EXTERNAL SERVICES (3rd Party Integrations)
  // ==========================================
  
  // SMTP Email Server (e.g. Gmail, SendGrid, Mailgun)
  emailHost: process.env.EMAIL_HOST,
  emailPort: process.env.EMAIL_PORT,
  emailUser: process.env.EMAIL_USER,
  emailPass: process.env.EMAIL_PASS,
  emailFrom: process.env.EMAIL_FROM, // e.g. "EaseInn Reservations <noreply@easeinn.com>"
  
  // Stripe Payment Gateway
  stripeSecretKey: process.env.STRIPE_SECRET_KEY,
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET, // Used to verify that "payment success" messages actually came from Stripe
  
  // Twilio SMS Gateway
  twilioAccountSid: process.env.TWILIO_ACCOUNT_SID,
  twilioAuthToken: process.env.TWILIO_AUTH_TOKEN,
  twilioPhoneNumber: process.env.TWILIO_PHONE_NUMBER,
  
  // ImgBB Image Hosting
  imgbbApiKey: process.env.IMGBB_API_KEY,
};

export default env;
export { env };

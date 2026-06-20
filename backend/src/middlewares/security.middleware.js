import helmet from 'helmet'; // Imports Helmet, a library that sets various HTTP headers to secure the app
import cors from 'cors'; // Imports CORS, a library to control which domains can talk to this API
import rateLimit from 'express-rate-limit'; // Imports a rate limiter to prevent spam/DDoS attacks
import env from '../config/env.config.js'; // Imports our environment variables

// ==========================================
// 1. HELMET SECURITY
// Adds essential HTTP headers to protect against common web vulnerabilities
// like Cross-Site Scripting (XSS) and Clickjacking.
// ==========================================
export const helmetMiddleware = helmet({
  // Disables the CSP header because it can sometimes block our own frontend scripts from running during development
  contentSecurityPolicy: false,
  // Disables the COEP header to avoid issues with loading cross-origin images or resources
  crossOriginEmbedderPolicy: false,
});

// ==========================================
// 2. CORS CONFIGURATION
// Cross-Origin Resource Sharing rules. Prevents random websites
// from making API requests to this backend unless allowed in env.
// ==========================================
const allowedOrigins = env.cors.origin
  ? env.cors.origin.split(',').map((o) => o.trim())
  : [];

export const corsMiddleware = cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
});

// ==========================================
// 3. RATE LIMITER (DDOS PROTECTION)
// Prevents spam by restricting the number of API requests
// a single IP address can make within a time window.
// ==========================================
export const rateLimiter = rateLimit({
  // The time window (e.g., 15 minutes) defined in our .env file
  windowMs: env.rateLimit.windowMs,
  // The maximum number of requests a single IP address can make during that window
  max: env.rateLimit.max,
  // Return rate limit info in the `RateLimit-*` headers to let the client know their status
  standardHeaders: true,
  // Disable the `X-RateLimit-*` legacy headers
  legacyHeaders: false,
  // The exact JSON message sent back to the hacker/user if they exceed the limit
  message: {
    success: false,
    message: 'Too many requests, please try again later.',
  },
});

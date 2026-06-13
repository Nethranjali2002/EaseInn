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
export const corsMiddleware = cors({
  // Only allows requests coming from the exact URL specified in our .env file (e.g., http://localhost:5000)
  origin: env.cors.origin,
  // Allows the API to accept cookies and authorization headers from the frontend
  credentials: true,
  // Specifically lists which HTTP methods the frontend is allowed to use
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  // Specifies which HTTP headers the frontend is allowed to send to us
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

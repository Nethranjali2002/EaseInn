import * as advancedController from '../controllers/advanced.controller.js'; // Imports the controller logic for AI and analytics
import * as passwordController from '../controllers/password.controller.js'; // Imports the controller for forgot/reset password logic
import { handleWebhook } from '../services/stripe.service.js'; // Imports the service that handles automated Stripe payment events
import { authenticate, authorize } from '../middlewares/auth.middleware.js'; // Imports our security guards
import express from 'express'; // Imports express to handle raw body parsing for Webhooks

const adminRoles = ['admin']; // Defines an array of roles allowed to access high-level analytics

// ==========================================
// 1. SETUP ADVANCED ROUTES
// This file separates complex/advanced endpoints (like Webhooks and AI)
// from the massive index.js file to keep the codebase clean.
// ==========================================
export const setupAdvancedRoutes = (router) => {
  // --------------------------------------------------------
  // A. PASSWORD MANAGEMENT
  // These routes are open to the public (no 'authenticate' middleware)
  // because users who forgot their password cannot log in to get a token!
  // --------------------------------------------------------
  router.post('/auth/forgot-password', passwordController.forgotPassword);
  router.post('/auth/reset-password', passwordController.resetPassword);
  router.post('/auth/change-password', passwordController.changePassword);

  // --------------------------------------------------------
  // B. STRIPE WEBHOOK (PAYMENT AUTOMATION)
  // When a guest pays on the Stripe checkout page, Stripe sends a silent
  // HTTP POST request to this endpoint to confirm the payment was successful.
  // --------------------------------------------------------
  // IMPORTANT: Stripe webhooks MUST receive raw JSON bytes, not parsed JSON, 
  // to verify the security signature. That is why we use express.raw() here.
  router.post('/webhook/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
    // Grab the security signature from Stripe's hidden HTTP headers
    const sig = req.headers['stripe-signature'];
    // Grab our secret webhook password from the .env file
    const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;
    let event;

    try {
      // Dynamically import the stripe library
      const stripe = (await import('stripe')).default;
      // Initialize Stripe using our master secret key
      const stripeInstance = new stripe(process.env.STRIPE_SECRET_KEY);
      
      // Cryptographically verify that this request actually came from Stripe and not a hacker.
      // If the signature matches, it constructs the verified event object.
      event = stripeInstance.webhooks.constructEvent(req.body, sig, endpointSecret);
    } catch (err) {
      // If the signature is fake, immediately block the request with a 400 error
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    // Pass the perfectly verified event to our Stripe Service to update the Booking status in MongoDB
    await handleWebhook(event);
    
    // Tell Stripe we received the message so they don't keep retrying it
    res.json({ received: true });
  });

  // --------------------------------------------------------
  // C. MULTI-PROPERTY ANALYTICS (ADMIN ONLY)
  // These endpoints pull massive amounts of data across all hotels.
  // We strictly protect them using both 'authenticate' AND 'authorize(admin)'.
  // --------------------------------------------------------
  router.get('/analytics/consolidated', authenticate, authorize(...adminRoles), advancedController.getConsolidatedReport);
  router.get('/analytics/consolidated/calendar', authenticate, authorize(...adminRoles), advancedController.getConsolidatedCalendar);

  // --------------------------------------------------------
  // D. AI & FORECASTING
  // Analyzes past bookings and market demand to suggest dynamic room prices.
  // --------------------------------------------------------
  router.get('/properties/:propertyId/analytics/pricing', advancedController.getAIPricingSuggestions);
  router.get('/properties/:propertyId/analytics/forecast', advancedController.getDemandForecast);
};

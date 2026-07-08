import * as advancedController from '../controllers/advanced.controller.js'; 
import * as passwordController from '../controllers/password.controller.js'; 
import { handleWebhook } from '../services/stripe.service.js'; 
import { authenticate, authorize } from '../middlewares/auth.middleware.js'; 
import express from 'express'; 

const adminRoles = ['admin']; 


//  complex/advanced endpoints (like Webhooks and AI)
export const setupAdvancedRoutes = (router) => {
  // A. PASSWORD MANAGEMENT
  router.post('/auth/forgot-password', passwordController.forgotPassword);
  router.post('/auth/reset-password', passwordController.resetPassword);
  router.post('/auth/change-password', passwordController.changePassword);

  // B. STRIPE WEBHOOK (PAYMENT AUTOMATION)
  router.post('/webhook/stripe', express.raw({ type: 'application/json' }), async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;
    let event;

    try {
      const stripe = (await import('stripe')).default;
      const stripeInstance = new stripe(process.env.STRIPE_SECRET_KEY);
      
      event = stripeInstance.webhooks.constructEvent(req.body, sig, endpointSecret);
    } catch (err) {
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    await handleWebhook(event);
    
    res.json({ received: true });
  });

  // C. MULTI-PROPERTY ANALYTICS (ADMIN ONLY)
  router.get('/analytics/consolidated', authenticate, authorize(...adminRoles), advancedController.getConsolidatedReport);
  router.get('/analytics/consolidated/calendar', authenticate, authorize(...adminRoles), advancedController.getConsolidatedCalendar);

  // D. AI & FORECASTING
  // Analyzes past bookings and market demand to suggest dynamic room prices.
  router.get('/properties/:propertyId/analytics/pricing', advancedController.getAIPricingSuggestions);
  router.get('/properties/:propertyId/analytics/forecast', advancedController.getDemandForecast);
};

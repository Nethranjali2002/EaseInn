import Stripe from 'stripe'; // The official Stripe Node.js SDK
import { env } from '../config/env.config.js'; // Environment variables, including the secret Stripe key
import Booking from '../models/booking.model.js'; // DB Model
import Payment from '../models/payment.model.js'; // DB Model
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP errors
import logger from './logger.util.js'; // Server logging tool

// Initialize Stripe ONLY if the environment variable exists. 
// If it's missing (like in local dev), the app won't crash, but checkout will fail gracefully.
let stripe;
if (env.stripeSecretKey) {
  stripe = new Stripe(env.stripeSecretKey);
}


// ==========================================
// 1. CREATE PAYMENT INTENT (Custom UI Flow)
// Used if the frontend builds its own custom credit card form using Stripe Elements
// ==========================================
export const createPaymentIntent = async (bookingId, amount, currency = 'lkr') => {
  // Prevent crashes if the server admin forgot to set up Stripe
  if (!stripe) throw new AppError('Payment gateway not configured', 503);

  const booking = await Booking.findById(bookingId);
  if (!booking) throw new AppError('Booking not found', 404);

  // Tell Stripe to expect a payment. Note: Stripe requires amounts to be in cents! (e.g. $10.00 = 1000)
  const paymentIntent = await stripe.paymentIntents.create({
    amount: Math.round(amount * 100),
    currency,
    // Attach invisible metadata so when Stripe webhooks us back, we know exactly which booking just got paid
    metadata: { bookingId: booking._id.toString(), propertyId: booking.property.toString() },
  });

  // The clientSecret is securely sent to the frontend so it can mount the credit card UI
  return {
    clientSecret: paymentIntent.clientSecret,
    paymentIntentId: paymentIntent.id,
  };
};


// ==========================================
// 2. CREATE CHECKOUT SESSION (Hosted UI Flow)
// Used when redirecting the user to Stripe's own pre-built, secure payment page
// ==========================================
export const createCheckoutSession = async (bookingId, successUrl, cancelUrl) => {
  if (!stripe) throw new AppError('Payment gateway not configured', 503);

  const booking = await Booking.findById(bookingId).populate('room');
  if (!booking) throw new AppError('Booking not found', 404);

  // Generate a temporary Stripe Checkout URL
  const session = await stripe.checkout.sessions.create({
    payment_method_types: ['card'],
    line_items: [{
      price_data: {
        currency: 'lkr',
        product_data: {
          // This is what the guest actually sees on their receipt
          name: `Room ${booking.room?.roomNumber || 'Booking'} - ${booking.guest?.name}`,
          description: `Check-in: ${booking.checkIn.toDateString()} | Check-out: ${booking.checkOut.toDateString()}`,
        },
        unit_amount: Math.round(booking.pricing.totalAmount * 100), // Convert to cents
      },
      quantity: 1,
    }],
    mode: 'payment',
    // Where Stripe should redirect the browser after they successfully pay
    success_url: successUrl || `${env.frontendUrl || 'http://localhost:3000'}/payment-success?session_id={CHECKOUT_SESSION_ID}`,
    // Where Stripe should redirect if they click the "Back" button
    cancel_url: cancelUrl || `${env.frontendUrl || 'http://localhost:3000'}/payment-cancel`,
    // Metadata for the webhook
    metadata: { bookingId: booking._id.toString() },
  });

  // Send the URL to the frontend so it can run `window.location.href = url`
  return { sessionId: session.id, url: session.url };
};


// ==========================================
// 3. HANDLE WEBHOOK
// A background listener. Stripe securely pings this function automatically the exact second a card is charged.
// ==========================================
export const handleWebhook = async (event) => {
  // We only care about the event that fires when a checkout page is successfully completed
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    
    // Extract the invisible metadata we attached in step 2
    const bookingId = session.metadata.bookingId;

    const booking = await Booking.findById(bookingId);
    if (!booking) return;

    // Prevent duplicate entries. If Stripe accidentally sends the webhook twice, we ignore the second one.
    const existingPayment = await Payment.findOne({
      booking: booking._id,
      'gateway.reference': session.id,
    });
    if (existingPayment) {
      logger.info(`Payment already recorded for Stripe session ${session.id}`);
      return;
    }

    // Since the webhook proved the money is in our bank, create a "completed" Payment record
    const payment = await Payment.create({
      property: booking.property,
      booking: booking._id,
      amount: session.amount_total / 100, // Convert cents back to standard dollars/rupees
      currency: session.currency.toUpperCase(),
      method: 'online',
      type: 'full',
      status: 'completed',
      // Store the exact Stripe IDs for accounting/refund purposes later
      gateway: {
        name: 'stripe',
        transactionId: session.payment_intent,
        reference: session.id,
        response: session,
      },
      paidAt: new Date(),
    });

    // Run the standard sync logic to tell the main Booking document that it is now paid off
    const totalPaid = await Payment.aggregate([
      { $match: { booking: booking._id, status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]);

    const amountPaid = totalPaid.length > 0 ? totalPaid[0].total : 0;
    const paymentStatus = amountPaid >= booking.pricing.totalAmount ? 'paid' : 'partial';

    await Booking.findByIdAndUpdate(bookingId, { amountPaid, paymentStatus });
    logger.info(`Payment completed for booking ${bookingId}: ${payment.amount}`);
  }
};

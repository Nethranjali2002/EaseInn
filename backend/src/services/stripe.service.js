import Stripe from 'stripe'; 
import { env } from '../config/env.config.js'; 
import Booking from '../models/booking.model.js'; 
import Payment from '../models/payment.model.js'; 
import { AppError } from '../middlewares/error.middleware.js'; 
import logger from './logger.util.js'; 

let stripe;
if (env.stripeSecretKey) {
  stripe = new Stripe(env.stripeSecretKey);
}


//Sends user to Stripe’s ready-made payment page
export const createPaymentIntent = async (bookingId, amount, currency = 'lkr') => {
  if (!stripe) throw new AppError('Payment gateway not configured', 503);

  const booking = await Booking.findById(bookingId);
  if (!booking) throw new AppError('Booking not found', 404);

  const paymentIntent = await stripe.paymentIntents.create({
    amount: Math.round(amount * 100),
    currency,
    metadata: { bookingId: booking._id.toString(), propertyId: booking.property.toString() },
  });

  return {
    clientSecret: paymentIntent.clientSecret,
    paymentIntentId: paymentIntent.id,
  };
};


export const createCheckoutSession = async (bookingId, successUrl, cancelUrl) => {
  if (!stripe) throw new AppError('Payment gateway not configured', 503);

  const booking = await Booking.findById(bookingId).populate('room');
  if (!booking) throw new AppError('Booking not found', 404);

  const session = await stripe.checkout.sessions.create({
    payment_method_types: ['card'],
    line_items: [{
      price_data: {
        currency: 'lkr',
        product_data: {
          name: `Room ${booking.room?.roomNumber || 'Booking'} - ${booking.guest?.name}`,
          description: `Check-in: ${booking.checkIn.toDateString()} | Check-out: ${booking.checkOut.toDateString()}`,
        },
        unit_amount: Math.round(booking.pricing.totalAmount * 100), // Convert to cents
      },
      quantity: 1,
    }],
    mode: 'payment',
    success_url: successUrl || `${env.frontendUrl || 'http://localhost:3000'}/payment-success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: cancelUrl || `${env.frontendUrl || 'http://localhost:3000'}/payment-cancel`,
    metadata: { bookingId: booking._id.toString() },
  });

  return { sessionId: session.id, url: session.url };
};


// 3. HANDLE WEBHOOK
//Runs automatically when Stripe confirms payment
export const handleWebhook = async (event) => {
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    
    const bookingId = session.metadata.bookingId;

    const booking = await Booking.findById(bookingId);
    if (!booking) return;

    const existingPayment = await Payment.findOne({
      booking: booking._id,
      'gateway.reference': session.id,
    });
    if (existingPayment) {
      logger.info(`Payment already recorded for Stripe session ${session.id}`);
      return;
    }

    const payment = await Payment.create({
      property: booking.property,
      booking: booking._id,
      amount: session.amount_total / 100, 
      currency: session.currency.toUpperCase(),
      method: 'online',
      type: 'full',
      status: 'completed',
      gateway: {
        name: 'stripe',
        transactionId: session.payment_intent,
        reference: session.id,
        response: session,
      },
      paidAt: new Date(),
    });

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

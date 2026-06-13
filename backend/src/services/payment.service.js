import Payment from '../models/payment.model.js'; // The database model for transactions/invoices
import Booking from '../models/booking.model.js'; // The database model for the reservation being paid for
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP errors
import { generatePaymentCode } from '../utils/codeGenerator.js'; // Helper to generate unique transaction IDs


// ==========================================
// 1. GENERATE INVOICE NUMBER (Helper)
// Creates a professional looking invoice number like "INV-LKF1A-X7YZ"
// ==========================================
const generateInvoiceNumber = (propertyId) => {
  const timestamp = Date.now().toString(36).toUpperCase(); // Convert current time to short string
  const random = Math.random().toString(36).substring(2, 6).toUpperCase(); // 4 random characters
  return `INV-${timestamp}-${random}`;
};


// ==========================================
// 2. CREATE PAYMENT
// Records a new transaction (cash, card, bank transfer)
// ==========================================
export const createPayment = async (data, recordedBy) => {
  const booking = await Booking.findById(data.booking);
  if (!booking) throw new AppError('Booking not found', 404);

  // If the front desk is recording a "Pending" payment (e.g. they sent a payment link to the guest but it's not paid yet)
  if (data.status !== 'completed') {
    const existingPending = await Payment.findOne({
      booking: booking._id,
      status: 'pending',
      amount: data.amount,
      method: data.method,
    });
    // Prevent duplicate pending requests for the exact same amount/method to avoid annoying the guest
    if (existingPending) {
      throw new AppError('A pending payment with the same amount and method already exists for this booking', 409);
    }
  }

  // If the payment is actually completed (money received)
  if (data.status === 'completed') {
    const existingCompleted = await Payment.findOne({
      booking: booking._id,
      status: 'completed',
      amount: data.amount,
      method: data.method,
      type: data.type || 'partial',
    });
    // Strict duplication check: Prevent a manager from double-clicking the "Submit Payment" button
    if (existingCompleted) {
      throw new AppError('A completed payment with the same amount and method already exists for this booking', 409);
    }

    // Financial Security: Calculate exactly how much money the guest still owes
    const outstanding = booking.pricing.totalAmount - booking.amountPaid;
    
    // Prevent over-charging. (+1 is a buffer for tiny currency floating point math errors)
    if (data.amount > outstanding + 1) {
      throw new AppError(`Payment amount (LKR ${data.amount}) exceeds outstanding balance (LKR ${outstanding})`, 400);
    }
  }

  // Actually save the payment record to the database
  const payment = await Payment.create({
    ...data,
    code: await generatePaymentCode(),
    property: booking.property,
    recordedBy, // The staff member ID who entered this cash into the system
    invoiceNumber: generateInvoiceNumber(booking.property),
    paidAt: data.status === 'completed' ? new Date() : undefined, // Stamp the exact time the money hit the account
  });

  // CRITICAL STEP: Sync the Payment to the Booking
  // If we just received money, we MUST update the main reservation to show they paid
  if (data.status === 'completed') {
    
    // Recalculate the absolute total amount of money we have ever received for this booking
    const totalPaid = await Payment.aggregate([
      { $match: { booking: booking._id, status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]);

    const amountPaid = totalPaid.length > 0 ? totalPaid[0].total : 0;
    
    // Determine the overall status of the reservation's finances
    const paymentStatus = amountPaid >= booking.pricing.totalAmount ? 'paid' : amountPaid > 0 ? 'partial' : 'pending';

    const bookingUpdates = { amountPaid, paymentStatus };
    
    // If they just paid it off completely (100%)
    if (paymentStatus === 'paid') {
      // If it was just sitting as "pending-payment", it is now officially "confirmed"
      if (booking.bookingStatus === 'pending-payment') {
        bookingUpdates.bookingStatus = 'confirmed';
      } 
      // If they had already checked out but owed us money, the reservation is now officially "completed"
      else if (booking.bookingStatus === 'checked-out') {
        bookingUpdates.bookingStatus = 'completed';
      }
    }

    // Save the synced data back to the Booking document
    await Booking.findByIdAndUpdate(booking._id, bookingUpdates);
  }

  return payment;
};


// ==========================================
// 3. GET PAYMENTS
// Fetches the transaction history table
// ==========================================
export const getPayments = async (propertyId, { page = 1, limit = 20, status, bookingId }) => {
  const query = { property: propertyId };
  if (status) query.status = status;
  if (bookingId) query.booking = bookingId;

  const total = await Payment.countDocuments(query);
  const payments = await Payment.find(query)
    .populate('booking', 'guest.name checkIn checkOut') // Pull the guest's name from the booking for the UI
    .populate('recordedBy', 'name email') // Show exactly which staff member accepted this money
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
    
  return { payments, total, page, limit };
};


// ==========================================
// 4. GET PAYMENT BY ID
// ==========================================
export const getPaymentById = async (paymentId) => {
  const payment = await Payment.findById(paymentId)
    .populate('booking', 'guest.name guest.email checkIn checkOut pricing')
    .populate('recordedBy', 'name email');
  if (!payment) throw new AppError('Payment not found', 404);
  return payment;
};


// ==========================================
// 5. UPDATE PAYMENT STATUS
// Usually called when an external gateway (like Stripe) confirms the money arrived
// ==========================================
export const updatePaymentStatus = async (paymentId, status, gatewayData) => {
  // Find the transaction and update it
  const payment = await Payment.findByIdAndUpdate(
    paymentId,
    {
      status,
      ...(gatewayData && { gateway: gatewayData }), // Save the Stripe receipt ID if provided
      ...(status === 'completed' && { paidAt: new Date() }), // Stamp the time
    },
    { new: true }
  );
  if (!payment) throw new AppError('Payment not found', 404);

  // CRITICAL STEP: Sync the updated payment to the Booking (Same exact logic as createPayment)
  if (status === 'completed') {
    const totalPaid = await Payment.aggregate([
      { $match: { booking: payment.booking, status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]);

    const amountPaid = totalPaid.length > 0 ? totalPaid[0].total : 0;
    const booking = await Booking.findById(payment.booking);
    const paymentStatus = amountPaid >= booking.pricing.totalAmount ? 'paid' : amountPaid > 0 ? 'partial' : 'pending';

    const bookingUpdates = { amountPaid, paymentStatus };
    if (paymentStatus === 'paid') {
      if (booking.bookingStatus === 'pending-payment') {
        bookingUpdates.bookingStatus = 'confirmed';
      } else if (booking.bookingStatus === 'checked-out') {
        bookingUpdates.bookingStatus = 'completed';
      }
    }

    await Booking.findByIdAndUpdate(payment.booking, bookingUpdates);
  }

  return payment;
};


// ==========================================
// 6. GET PAYMENT STATS
// Quickly calculates "Total Revenue" and "Revenue Today" for the dashboard widgets
// ==========================================
export const getPaymentStats = async (propertyId) => {
  const today = new Date();
  today.setHours(0, 0, 0, 0); // Set time to midnight to catch the whole day

  // Sum literally all money ever made by this hotel
  const totalRevenue = await Payment.aggregate([
    { $match: { property: propertyId, status: 'completed', type: { $ne: 'refund' } } },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);

  // Sum only the money made today
  const todayRevenue = await Payment.aggregate([
    { $match: { property: propertyId, status: 'completed', type: { $ne: 'refund' }, paidAt: { $gte: today } } },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);

  return {
    totalRevenue: totalRevenue.length > 0 ? totalRevenue[0].total : 0,
    todayRevenue: todayRevenue.length > 0 ? todayRevenue[0].total : 0,
  };
};

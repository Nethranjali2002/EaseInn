import * as paymentService from '../services/payment.service.js'; // Imports the Brain that handles financial transactions
import { sendSuccess } from '../utils/response.util.js'; // Helper for formatting JSON responses
import { logAudit } from '../utils/audit.util.js'; // Records financial actions securely
import { sendPaymentReceivedNotification } from '../utils/push.util.js'; // Helper for sending automated SMS/Email receipts


// ==========================================
// 1. CREATE PAYMENT
// ==========================================
export const createPayment = async (req, res, next) => {
  try {
    // Pass the raw payment data (amount, credit card details, booking ID) and the user recording the payment to the Service
    const payment = await paymentService.createPayment(req.body, req.user.sub);
    
    // Crucial security step: Log exactly who processed this payment and for how much
    await logAudit({ user: req.user.sub, action: 'payment', entity: 'Payment', entityId: payment._id, description: `Payment of ${payment.amount} ${payment.currency}`, ip: req.ip });
    
    // Automatically email/push a receipt to the guest
    await sendPaymentReceivedNotification(payment).catch(() => {});
    
    // Respond with a 201 Created and the payment record
    return sendSuccess(res, { statusCode: 201, message: 'Payment recorded', data: { payment } });
  } catch (err) { return next(err); }
};


// ==========================================
// 2. GET PAYMENTS
// ==========================================
export const getPayments = async (req, res, next) => {
  try {
    // Extract filters (e.g., status='completed', or filter by a specific bookingId)
    const { page, limit, status, bookingId } = req.query;
    
    // Pass the property ID and filters to the Service to fetch the financial ledger
    const result = await paymentService.getPayments(req.params.propertyId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, status, bookingId });
    
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};


// ==========================================
// 3. GET PAYMENT BY ID
// ==========================================
export const getPaymentById = async (req, res, next) => {
  try {
    // Fetch a single transaction's full details (e.g., to print a specific invoice)
    const payment = await paymentService.getPaymentById(req.params.id);
    return sendSuccess(res, { data: { payment } });
  } catch (err) { return next(err); }
};


// ==========================================
// 4. UPDATE PAYMENT STATUS
// ==========================================
export const updatePaymentStatus = async (req, res, next) => {
  try {
    // Allows updating a 'pending' payment to 'completed' or 'failed', usually triggered by the Stripe Webhook
    const payment = await paymentService.updatePaymentStatus(req.params.id, req.body.status, req.body.gateway);
    
    // Log the exact status change in the Audit Logs
    await logAudit({ user: req.user.sub, action: 'payment', entity: 'Payment', entityId: payment._id, description: `Payment status: ${payment.status}`, ip: req.ip });
    
    return sendSuccess(res, { message: 'Payment updated', data: { payment } });
  } catch (err) { return next(err); }
};


// ==========================================
// 5. GET PAYMENT STATS
// ==========================================
export const getPaymentStats = async (req, res, next) => {
  try {
    // Fetches aggregated financial math (Total Revenue, Pending Balances, Refund Rates) for the dashboard
    const stats = await paymentService.getPaymentStats(req.params.propertyId);
    return sendSuccess(res, { data: stats });
  } catch (err) { return next(err); }
};

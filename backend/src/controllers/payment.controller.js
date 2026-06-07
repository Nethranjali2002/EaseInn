import * as paymentService from '../services/payment.service.js';
import { sendSuccess } from '../utils/response.util.js';
import { logAudit } from '../utils/audit.util.js';
import { sendPaymentReceivedNotification } from '../utils/push.util.js';

export const createPayment = async (req, res, next) => {
  try {
    const payment = await paymentService.createPayment(req.body, req.user.sub);
    await logAudit({ user: req.user.sub, action: 'payment', entity: 'Payment', entityId: payment._id, description: `Payment of ${payment.amount} ${payment.currency}`, ip: req.ip });
    await sendPaymentReceivedNotification(payment).catch(() => {});
    return sendSuccess(res, { statusCode: 201, message: 'Payment recorded', data: { payment } });
  } catch (err) { return next(err); }
};

export const getPayments = async (req, res, next) => {
  try {
    const { page, limit, status, bookingId } = req.query;
    const result = await paymentService.getPayments(req.params.propertyId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, status, bookingId });
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

export const getPaymentById = async (req, res, next) => {
  try {
    const payment = await paymentService.getPaymentById(req.params.id);
    return sendSuccess(res, { data: { payment } });
  } catch (err) { return next(err); }
};

export const updatePaymentStatus = async (req, res, next) => {
  try {
    const payment = await paymentService.updatePaymentStatus(req.params.id, req.body.status, req.body.gateway);
    await logAudit({ user: req.user.sub, action: 'payment', entity: 'Payment', entityId: payment._id, description: `Payment status: ${payment.status}`, ip: req.ip });
    return sendSuccess(res, { message: 'Payment updated', data: { payment } });
  } catch (err) { return next(err); }
};

export const getPaymentStats = async (req, res, next) => {
  try {
    const stats = await paymentService.getPaymentStats(req.params.propertyId);
    return sendSuccess(res, { data: stats });
  } catch (err) { return next(err); }
};

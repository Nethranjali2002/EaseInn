import * as feedbackService from '../services/feedback.service.js';
import { sendSuccess } from '../utils/response.util.js';
import { logAudit } from '../utils/audit.util.js';

export const createFeedback = async (req, res, next) => {
  try {
    const feedback = await feedbackService.createFeedback(req.body);
    return sendSuccess(res, { statusCode: 201, message: 'Feedback submitted', data: { feedback } });
  } catch (err) { return next(err); }
};

export const getFeedback = async (req, res, next) => {
  try {
    const { page, limit, minRating } = req.query;
    const result = await feedbackService.getFeedback(req.params.propertyId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, minRating: minRating ? parseInt(minRating) : undefined });
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

export const getFeedbackStats = async (req, res, next) => {
  try {
    const stats = await feedbackService.getFeedbackStats(req.params.propertyId);
    return sendSuccess(res, { data: stats });
  } catch (err) { return next(err); }
};

export const respondToFeedback = async (req, res, next) => {
  try {
    const feedback = await feedbackService.respondToFeedback(req.params.id, req.user.sub, req.body.text);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Feedback', entityId: req.params.id, description: 'Response added to feedback', ip: req.ip, userAgent: req.get('user-agent') });
    return sendSuccess(res, { message: 'Response added', data: { feedback } });
  } catch (err) { return next(err); }
};

export const resolveFeedback = async (req, res, next) => {
  try {
    const feedback = await feedbackService.resolveFeedback(req.params.id, req.user.sub);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Feedback', entityId: req.params.id, description: 'Feedback marked as resolved', ip: req.ip, userAgent: req.get('user-agent') });
    return sendSuccess(res, { message: 'Feedback resolved', data: { feedback } });
  } catch (err) { return next(err); }
};

export const toggleFeedbackVisibility = async (req, res, next) => {
  try {
    const Feedback = (await import('../models/feedback.model.js')).default;
    const feedback = await Feedback.findByIdAndUpdate(
      req.params.id,
      { isPublic: req.body.isPublic },
      { new: true }
    );
    if (!feedback) {
      const { AppError } = await import('../middlewares/error.middleware.js');
      throw new AppError('Feedback not found', 404);
    }
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Feedback', entityId: req.params.id, description: `Feedback visibility set to ${req.body.isPublic}`, ip: req.ip });
    return sendSuccess(res, { message: 'Feedback visibility updated', data: { feedback } });
  } catch (err) { return next(err); }
};

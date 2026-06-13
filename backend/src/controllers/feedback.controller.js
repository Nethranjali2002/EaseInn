import * as feedbackService from '../services/feedback.service.js'; // Imports the Brain handling guest complaints and ratings
import { sendSuccess } from '../utils/response.util.js'; // Helper for formatting JSON responses
import { logAudit } from '../utils/audit.util.js'; // Records when staff reply to or resolve feedback


// ==========================================
// 1. CREATE FEEDBACK
// ==========================================
export const createFeedback = async (req, res, next) => {
  try {
    // Allows staff to manually log a piece of feedback or complaint received at the front desk
    const feedback = await feedbackService.createFeedback(req.body);
    return sendSuccess(res, { statusCode: 201, message: 'Feedback submitted', data: { feedback } });
  } catch (err) { return next(err); }
};


// ==========================================
// 2. GET FEEDBACK
// ==========================================
export const getFeedback = async (req, res, next) => {
  try {
    // Fetch a paginated list of feedback, optionally filtering out bad reviews (e.g. minRating=4)
    const { page, limit, minRating } = req.query;
    
    const result = await feedbackService.getFeedback(req.params.propertyId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, minRating: minRating ? parseInt(minRating) : undefined });
    
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};


// ==========================================
// 3. GET FEEDBACK STATS
// ==========================================
export const getFeedbackStats = async (req, res, next) => {
  try {
    // Fetches math for the dashboard: Average Rating (e.g., 4.5/5) and Number of Unresolved Complaints
    const stats = await feedbackService.getFeedbackStats(req.params.propertyId);
    return sendSuccess(res, { data: stats });
  } catch (err) { return next(err); }
};


// ==========================================
// 4. RESPOND TO FEEDBACK
// ==========================================
export const respondToFeedback = async (req, res, next) => {
  try {
    // Allows a Manager to write a response to a guest review (e.g., "Thank you for staying!")
    const feedback = await feedbackService.respondToFeedback(req.params.id, req.user.sub, req.body.text);
    
    // Log exactly which manager posted the response
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Feedback', entityId: req.params.id, description: 'Response added to feedback', ip: req.ip, userAgent: req.get('user-agent') });
    
    return sendSuccess(res, { message: 'Response added', data: { feedback } });
  } catch (err) { return next(err); }
};


// ==========================================
// 5. RESOLVE FEEDBACK
// ==========================================
export const resolveFeedback = async (req, res, next) => {
  try {
    // Marks a negative complaint as 'Resolved' after the staff has fixed the issue
    const feedback = await feedbackService.resolveFeedback(req.params.id, req.user.sub);
    
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Feedback', entityId: req.params.id, description: 'Feedback marked as resolved', ip: req.ip, userAgent: req.get('user-agent') });
    
    return sendSuccess(res, { message: 'Feedback resolved', data: { feedback } });
  } catch (err) { return next(err); }
};


// ==========================================
// 6. TOGGLE FEEDBACK VISIBILITY
// ==========================================
export const toggleFeedbackVisibility = async (req, res, next) => {
  try {
    // Allows an Admin to hide a review from the public website if it contains inappropriate content
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

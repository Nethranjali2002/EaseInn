import Feedback from '../models/feedback.model.js';
import Booking from '../models/booking.model.js';
import { AppError } from '../middlewares/error.middleware.js';

export const createFeedback = async (data) => {
  const booking = await Booking.findById(data.booking);
  if (!booking) throw new AppError('Booking not found', 404);

  const existing = await Feedback.findOne({ booking: data.booking });
  if (existing) throw new AppError('Feedback already submitted for this booking', 409);

  const feedback = await Feedback.create({
    ...data,
    property: booking.property,
    guestName: booking.guest.name,
    guestEmail: booking.guest.email,
  });
  return feedback;
};

export const getFeedback = async (propertyId, { page = 1, limit = 20, minRating }) => {
  const query = { property: propertyId };
  if (minRating) query.rating = { $gte: minRating };

  const total = await Feedback.countDocuments(query);
  const feedback = await Feedback.find(query)
    .populate('booking', 'guest.name checkIn checkOut')
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
  return { feedback, total, page, limit };
};

export const getFeedbackStats = async (propertyId) => {
  const stats = await Feedback.aggregate([
    { $match: { property: propertyId } },
    {
      $group: {
        _id: null,
        avgRating: { $avg: '$rating' },
        totalReviews: { $sum: 1 },
        fiveStar: { $sum: { $cond: [{ $eq: ['$rating', 5] }, 1, 0] } },
        fourStar: { $sum: { $cond: [{ $eq: ['$rating', 4] }, 1, 0] } },
        threeStar: { $sum: { $cond: [{ $eq: ['$rating', 3] }, 1, 0] } },
        twoStar: { $sum: { $cond: [{ $eq: ['$rating', 2] }, 1, 0] } },
        oneStar: { $sum: { $cond: [{ $eq: ['$rating', 1] }, 1, 0] } },
      },
    },
  ]);

  return stats.length > 0
    ? stats[0]
    : { avgRating: 0, totalReviews: 0, fiveStar: 0, fourStar: 0, threeStar: 0, twoStar: 0, oneStar: 0 };
};

export const respondToFeedback = async (feedbackId, userId, text) => {
  const feedback = await Feedback.findById(feedbackId);
  if (!feedback) throw new AppError('Feedback not found', 404);
  
  feedback.response = { text, respondedBy: userId, respondedAt: new Date() };
  if (feedback.status === 'New') {
    feedback.status = 'Reviewed';
  }
  await feedback.save();
  return feedback;
};

export const resolveFeedback = async (feedbackId, userId) => {
  const feedback = await Feedback.findByIdAndUpdate(
    feedbackId,
    { status: 'Resolved', resolvedBy: userId, resolutionDate: new Date() },
    { new: true }
  );
  if (!feedback) throw new AppError('Feedback not found', 404);
  return feedback;
};

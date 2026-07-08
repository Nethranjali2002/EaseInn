import Booking from '../models/booking.model.js';
import Feedback from '../models/feedback.model.js';
import User from '../models/user.model.js';
import { sendSuccess } from '../utils/response.util.js';
import { AppError } from '../middlewares/error.middleware.js';
import { createNotification } from '../services/notification.service.js';
import logger from '../utils/logger.util.js';

export const validateReviewToken = async (req, res, next) => {
  try {
    const { token } = req.query;
    if (!token) throw new AppError('Review token is required', 400);
    const booking = await Booking.findOne({
      reviewToken: token,
      reviewTokenExpiresAt: { $gt: new Date() },
      reviewSubmitted: false,
      bookingStatus: { $in: ['checked-out', 'completed'] },
    })
      .populate('property', 'name address')
      .populate('room', 'roomNumber roomType name');
    if (!booking) {
      throw new AppError(
        'This review link is invalid, has expired, or has already been used.',
        400
      );
    }
    return sendSuccess(res, {
      data: {
        guestName: booking.guest.name,
        propertyName: booking.property?.name || 'EaseInn',
        propertyCity: booking.property?.address?.city || '',
        roomNumber: booking.room?.roomNumber || 'N/A',
        roomType: booking.room?.roomType || '',
        checkIn: booking.checkIn,
        checkOut: booking.checkOut,
      },
    });
  } catch (err) {
    return next(err);
  }
};

export const submitReview = async (req, res, next) => {
  try {
    const { token, rating, title, comment, categories, recommendation } = req.body;
    const booking = await Booking.findOne({
      reviewToken: token,
      reviewTokenExpiresAt: { $gt: new Date() },
      reviewSubmitted: false,
      bookingStatus: { $in: ['checked-out', 'completed'] },
    })
      .populate('property', 'name')
      .populate('room', 'roomNumber');
    if (!booking) {
      throw new AppError(
        'This review link is invalid, has expired, or has already been used.',
        400
      );
    }
    const existing = await Feedback.findOne({ booking: booking._id });
    if (existing) throw new AppError('A review has already been submitted for this booking', 409);
    const feedback = await Feedback.create({
      property: booking.property._id,
      booking: booking._id,
      guestName: booking.guest.name,
      guestEmail: booking.guest.email,
      rating,
      title: title || '',
      comment: comment || '',
      categories: categories || {},
      recommendation: recommendation || 'Yes',
      status: 'New',
      isPublic: true,
    });
    await Booking.findByIdAndUpdate(booking._id, {
      reviewSubmitted: true,
      $unset: { reviewToken: 1, reviewTokenExpiresAt: 1 },
    });
    try {
      const managers = await User.find({
        role: { $in: ['admin', 'manager'] },
        isActive: true,
      }).select('_id');
      const stars = '⭐'.repeat(rating);
      await Promise.all(
        managers.map((m) =>
          createNotification({
            recipient: m._id,
            property: booking.property._id,
            type: 'feedback_received',
            title: `New ${rating}-Star Review ${stars}`,
            message: `${booking.guest.name} left a ${rating}-star review for ${booking.property.name}`,
            data: { feedbackId: feedback._id, bookingId: booking._id },
          }).catch(() => {})
        )
      );
    } catch (notifErr) {
      logger.error(`Review notification failed: ${notifErr.message}`);
    }
    return sendSuccess(res, {
      statusCode: 201,
      message: 'Thank you! Your review has been submitted successfully.',
      data: { feedback },
    });
  } catch (err) {
    return next(err);
  }
};

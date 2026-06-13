import Booking from '../models/booking.model.js'; // Imports the Booking Database logic
import Feedback from '../models/feedback.model.js'; // Imports the Feedback Database logic
import User from '../models/user.model.js'; // Imports the User (Staff) Database logic
import { sendSuccess } from '../utils/response.util.js'; // Helper to send beautiful JSON responses
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP error codes
import { createNotification } from '../services/notification.service.js'; // Helper to send alerts to the bell icon
import logger from '../utils/logger.util.js'; // Helper to log silent errors to the server console


// ==========================================
// 1. VALIDATE REVIEW TOKEN (Public Route)
// When a guest clicks the "Leave a Review" link in their email, we must verify the link is real.
// ==========================================
export const validateReviewToken = async (req, res, next) => {
  try {
    // Extract the cryptographic token from the URL (e.g. ?token=abc123xyz)
    const { token } = req.query;
    if (!token) throw new AppError('Review token is required', 400);

    // Look for a booking that matches this exact token, hasn't expired, and belongs to a guest who actually checked out
    const booking = await Booking.findOne({
      reviewToken: token,
      reviewTokenExpiresAt: { $gt: new Date() },
      reviewSubmitted: false, // Prevents them from reviewing twice
      bookingStatus: { $in: ['checked-out', 'completed'] },
    })
      .populate('property', 'name address')
      .populate('room', 'roomNumber roomType name');

    // If the token is fake, expired, or already used, block the request
    if (!booking) {
      throw new AppError(
        'This review link is invalid, has expired, or has already been used.',
        400
      );
    }

    // If the token is valid, send back the basic booking info so the Frontend can say "How was your stay in Room 101, John?"
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


// ==========================================
// 2. SUBMIT REVIEW (Public Route)
// Handles the actual form submission when the guest clicks "Post Review"
// ==========================================
export const submitReview = async (req, res, next) => {
  try {
    // Extract all the review data from the form
    const { token, rating, title, comment, categories, recommendation } = req.body;

    // Verify the token AGAIN to prevent hackers from bypassing the validation step
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

    // Extra safety guard: Physically check if a review for this booking already exists in the Feedback table
    const existing = await Feedback.findOne({ booking: booking._id });
    if (existing) throw new AppError('A review has already been submitted for this booking', 409);

    // Create the actual review document in the database
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
      isPublic: true, // Default to public so it shows on the website immediately
    });

    // Mark the booking as "Reviewed" and destroy the token so the link can never be used again
    await Booking.findByIdAndUpdate(booking._id, {
      reviewSubmitted: true,
      $unset: { reviewToken: 1, reviewTokenExpiresAt: 1 },
    });

    // --- NOTIFICATION SYSTEM ---
    // Automatically find all Admins and Managers and ping their dashboard bell icon
    try {
      const managers = await User.find({
        role: { $in: ['admin', 'manager'] },
        isActive: true,
      }).select('_id');

      // Create a visual string of stars (e.g. "⭐⭐⭐⭐⭐")
      const stars = '⭐'.repeat(rating);
      
      // Send the ping to every single manager in parallel
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
      // If notifications fail, don't crash the review submission. Just log the error silently.
      logger.error(`Review notification failed: ${notifErr.message}`);
    }

    // Tell the guest their review was successful
    return sendSuccess(res, {
      statusCode: 201,
      message: 'Thank you! Your review has been submitted successfully.',
      data: { feedback },
    });
  } catch (err) {
    return next(err);
  }
};


import { Router } from 'express'; 
import * as authController from '../controllers/auth.controller.js';
import * as userController from '../controllers/user.controller.js';
import * as propertyController from '../controllers/property.controller.js';
import * as roomController from '../controllers/room.controller.js';
import * as bookingController from '../controllers/booking.controller.js';
import * as taskController from '../controllers/task.controller.js';
import * as paymentController from '../controllers/payment.controller.js';
import * as feedbackController from '../controllers/feedback.controller.js';
import * as reviewController from '../controllers/review.controller.js';
import * as notificationController from '../controllers/notification.controller.js';
import * as analyticsController from '../controllers/analytics.controller.js';
import * as advancedController from '../controllers/advanced.controller.js';
import * as exportController from '../controllers/export.controller.js';
import * as passwordController from '../controllers/password.controller.js';
import * as auditController from '../controllers/audit.controller.js';

import { authenticate, authorize } from '../middlewares/auth.middleware.js'; 
import validate from '../middlewares/validate.middleware.js'; 

import { uploadSingle, uploadMultiple } from '../utils/upload.util.js';
import { uploadFileToImgBB, uploadMultipleToImgBB } from '../utils/imgbb.util.js';

// --- VALIDATION SCHEMAS 
import {
  registerSchema,
  loginSchema,
  refreshSchema,
  updateProfileSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
  changePasswordSchema,
  createUserSchema,
  updateUserSchema,
  updateUserRoleSchema,
  toggleUserStatusSchema,
} from '../validators/auth.validator.js';
import {
  createPropertySchema,
  updatePropertySchema,
  createRoomSchema,
  updateRoomSchema,
  createBookingSchema,
  updateBookingSchema,
  createTaskSchema,
  updateTaskSchema,
  completeTaskSchema,
  createPaymentSchema,
  respondFeedbackSchema,
  submitReviewSchema,
  guestBookingSchema,
} from '../validators/domain.validator.js';

const router = Router();

const managerRoles = ['admin', 'manager']; 
const staffRoles = ['admin', 'manager', 'staff']; 

/*
  @swagger
  tags:
    - name: Health
      description: Health check
    - name: Auth
      description: Authentication & authorization
    - name: Users
      description: User profile management
    - name: Admin
      description: Admin-only user management
    - name: Properties
      description: Property CRUD
    - name: Rooms
      description: Room CRUD
    - name: Bookings
      description: Booking management
    - name: Tasks
      description: Task management
    - name: Payments
      description: Payment processing
    - name: Feedback
      description: Guest feedback
    - name: Notifications
      description: In-app notifications
    - name: Analytics
      description: Reports & analytics
    - name: Upload
      description: File uploads
    - name: Guest
      description: Public guest endpoints
*/

// ===================== PUBLIC =====================
/**
 * @swagger
 * /health:
 *   get:
 *     tags: [Health]
 *     summary: Health check endpoint
 *     responses:
 *       200:
 *         description: Service is healthy
 */
router.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

//DASHBOARD STATS
router.get('/dashboard/stats', authenticate, async (req, res, next) => {
  try {
    const Room = (await import('../models/room.model.js')).default;
    const Booking = (await import('../models/booking.model.js')).default;
    const Task = (await import('../models/task.model.js')).default;
    const Payment = (await import('../models/payment.model.js')).default;
    const Property = (await import('../models/property.model.js')).default;
    const Feedback = (await import('../models/feedback.model.js')).default;

    const properties = await Property.find({ isActive: true });
    const propertyIds = properties.map(p => p._id);

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    // Room stats
    const totalRooms = await Room.countDocuments({ isActive: true });
    const availableRooms = await Room.countDocuments({ isActive: true, status: 'available' });
    const bookedRooms = await Room.countDocuments({ isActive: true, status: 'occupied' });
    const maintenanceRooms = await Room.countDocuments({ isActive: true, status: 'maintenance' });

    // Booking stats
    const activeBookings = await Booking.countDocuments({ bookingStatus: { $in: ['confirmed', 'checked-in', 'pending-payment'] } });
    const confirmedBookings = await Booking.countDocuments({ bookingStatus: 'confirmed' });
    const checkedInBookings = await Booking.countDocuments({ bookingStatus: 'checked-in' });
    const checkedOutBookings = await Booking.countDocuments({ bookingStatus: { $in: ['checked-out', 'completed'] } });
    const cancelledBookings = await Booking.countDocuments({ bookingStatus: 'cancelled' });
    const todayCheckIns = await Booking.countDocuments({ checkIn: { $gte: today, $lt: tomorrow }, bookingStatus: { $in: ['confirmed', 'checked-in'] } });
    const todayCheckOuts = await Booking.countDocuments({ checkOut: { $gte: today, $lt: tomorrow }, bookingStatus: { $in: ['checked-in', 'checked-out'] } });
    const tomorrowCheckIns = await Booking.countDocuments({ checkIn: { $gte: tomorrow, $lt: new Date(tomorrow.getTime() + 86400000) }, bookingStatus: { $in: ['confirmed', 'pending-payment'] } });

    // Revenue stats
    const revenueAgg = await Payment.aggregate([
      { $match: { status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);
    const totalRevenue = revenueAgg[0]?.total || 0;

    const todayRevenueAgg = await Payment.aggregate([
      { $match: { status: 'completed', type: { $ne: 'refund' }, paidAt: { $gte: today, $lt: tomorrow } } },
      { $group: { _id: null, total: { $sum: '$amount' } } }
    ]);
    const todayRevenue = todayRevenueAgg[0]?.total || 0;

    // Monthly revenue trend (last 6 months)
    const sixMonthsAgo = new Date();
    sixMonthsAgo.setMonth(sixMonthsAgo.getMonth() - 6);
    const monthlyRevenue = await Payment.aggregate([
      { $match: { status: 'completed', type: { $ne: 'refund' }, paidAt: { $gte: sixMonthsAgo } } },
      { $group: { _id: { year: { $year: '$paidAt' }, month: { $month: '$paidAt' } }, total: { $sum: '$amount' } } },
      { $sort: { '_id.year': 1, '_id.month': 1 } }
    ]);

    // Task stats
    const openTasks = await Task.countDocuments({ status: 'open' });
    const inProgressTasks = await Task.countDocuments({ status: 'in-progress' });
    const overdueTasks = await Task.countDocuments({ status: { $in: ['open', 'in-progress'] }, dueDate: { $lt: new Date() } });
    const completedTasks = await Task.countDocuments({ status: 'completed' });

    // Feedback/rating
    const feedbackAgg = await Feedback.aggregate([
      { $match: { rating: { $exists: true, $ne: null } } },
      { $group: { _id: null, avg: { $avg: '$rating' }, count: { $sum: 1 } } }
    ]);
    const avgRating = feedbackAgg[0]?.avg ? Math.round(feedbackAgg[0].avg * 10) / 10 : 0;
    const totalReviews = feedbackAgg[0]?.count || 0;

    // Per-property performance
    const propertyPerformance = await Promise.all(properties.map(async (p) => {
      const pRooms = await Room.countDocuments({ property: p._id, isActive: true });
      const pBookings = await Booking.countDocuments({ property: p._id, bookingStatus: { $in: ['confirmed', 'checked-in'] } });
      const pRevAgg = await Payment.aggregate([
        { $match: { property: p._id, status: 'completed', type: { $ne: 'refund' } } },
        { $group: { _id: null, total: { $sum: '$amount' } } }
      ]);
      const pOpenTasks = await Task.countDocuments({ property: p._id, status: { $in: ['open', 'in-progress'] } });
      const occupancy = pRooms > 0 ? Math.round((pBookings / pRooms) * 100) : 0;
      return {
        id: p._id,
        name: p.name,
        rooms: pRooms,
        occupancy,
        revenue: pRevAgg[0]?.total || 0,
        openTasks: pOpenTasks,
      };
    }));

    return res.json({
      success: true,
      data: {
        properties: properties.length,
        totalRooms, availableRooms, bookedRooms, maintenanceRooms,
        activeBookings, confirmedBookings, checkedInBookings, checkedOutBookings, cancelledBookings,
        todayCheckIns, todayCheckOuts, tomorrowCheckIns,
        totalRevenue, todayRevenue, monthlyRevenue,
        openTasks, inProgressTasks, overdueTasks, completedTasks,
        avgRating, totalReviews,
        propertyPerformance,
      }
    });
  } catch (err) { return next(err); }
});

// ===================== EMAIL TEST (Admin only, dev/test use) =====================
router.post('/admin/test-email', authenticate, authorize('admin'), async (req, res, next) => {
  try {
    const { to } = req.body;
    if (!to) return res.status(400).json({ success: false, message: 'Provide a "to" email address in the request body' });

    const { sendReviewInvitation } = await import('../utils/email.util.js');
    const { env } = await import('../config/env.config.js');

    if (!env.emailUser) {
      return res.status(503).json({
        success: false,
        message: 'Email is not configured. Set EMAIL_USER and EMAIL_PASS in your .env file.',
      });
    }

    await sendReviewInvitation(to, 'Test Guest', {
      propertyName: 'EaseInn Test Property',
      roomNumber: '101',
      checkIn: new Date(),
      checkOut: new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
      reviewLink: `${env.appUrl}/#/web/review?token=test-token-preview`,
    });

    return res.json({ success: true, message: `✅ Test review invitation email sent to ${to}` });
  } catch (err) {
    return next(err);
  }
});


/**
 * @swagger
 * /auth/register:
 *   post:
 *     tags: [Auth]
 *     summary: Register a new user account
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [name, email, password]
 *             properties:
 *               name:
 *                 type: string
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       201:
 *         description: User registered successfully
 *       400:
 *         description: Validation error
 *       409:
 *         description: Email already exists
 */
router.post('/auth/register', validate(registerSchema), authController.register);

/**
 * @swagger
 * /auth/login:
 *   post:
 *     tags: [Auth]
 *     summary: Login with email and password
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email, password]
 *             properties:
 *               email:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login successful
 *       401:
 *         description: Invalid credentials
 */
router.post('/auth/login', validate(loginSchema), authController.login);

/**
 * @swagger
 * /auth/refresh:
 *   post:
 *     tags: [Auth]
 *     summary: Refresh access token
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [refreshToken]
 *             properties:
 *               refreshToken:
 *                 type: string
 *     responses:
 *       200:
 *         description: Token refreshed
 *       401:
 *         description: Invalid refresh token
 */
router.post('/auth/refresh', validate(refreshSchema), authController.refresh);

/**
 * @swagger
 * /auth/forgot-password:
 *   post:
 *     tags: [Auth]
 *     summary: Request password reset email
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [email]
 *             properties:
 *               email:
 *                 type: string
 *     responses:
 *       200:
 *         description: Reset email sent
 *       404:
 *         description: User not found
 */
router.post('/auth/forgot-password', validate(forgotPasswordSchema), passwordController.forgotPassword);

/**
 * @swagger
 * /auth/reset-password:
 *   post:
 *     tags: [Auth]
 *     summary: Reset password with token
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [token, password]
 *             properties:
 *               token:
 *                 type: string
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Password reset successful
 *       400:
 *         description: Invalid or expired token
 */
router.post('/auth/reset-password', validate(resetPasswordSchema), passwordController.resetPassword);

/**
 * @swagger
 * /feedback:
 *   post:
 *     tags: [Feedback]
 *     summary: Submit guest feedback (public)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               property:
 *                 type: string
 *               rating:
 *                 type: integer
 *               comment:
 *                 type: string
 *     responses:
 *       201:
 *         description: Feedback submitted
 *       400:
 *         description: Validation error
 */
router.post('/feedback', feedbackController.createFeedback);

/**
 * @swagger
 * /review/validate:
 *   get:
 *     tags: [Feedback]
 *     summary: Validate a review token (public) - returns booking details for review form
 *     parameters:
 *       - in: query
 *         name: token
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Token valid, returns booking details
 *       400:
 *         description: Invalid or expired token
 */
router.get('/review/validate', reviewController.validateReviewToken);

/**
 * @swagger
 * /review/submit:
 *   post:
 *     tags: [Feedback]
 *     summary: Submit a guest review via token (public)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [token, rating]
 *             properties:
 *               token:
 *                 type: string
 *               rating:
 *                 type: integer
 *                 minimum: 1
 *                 maximum: 5
 *               title:
 *                 type: string
 *               comment:
 *                 type: string
 *               categories:
 *                 type: object
 *     responses:
 *       201:
 *         description: Review submitted successfully
 *       400:
 *         description: Invalid token or validation error
 *       409:
 *         description: Review already submitted
 */
router.post('/review/submit', validate(submitReviewSchema), reviewController.submitReview);

/**
 * @swagger
 * /guest/booking:
 *   get:
 *     tags: [Guest]
 *     summary: Look up booking by reference or email
 *     parameters:
 *       - in: query
 *         name: ref
 *         required: true
 *         schema:
 *           type: string
 *         description: Booking ID or guest email
 *     responses:
 *       200:
 *         description: Booking found
 *       400:
 *         description: Reference required
 *       404:
 *         description: Booking not found
 */
router.get('/guest/booking', async (req, res) => {
  const Booking = (await import('../models/booking.model.js')).default;
  const { ref } = req.query;
  if (!ref) return res.status(400).json({ success: false, message: 'Reference required' });
  const booking = await Booking.findOne({
    $or: [{ _id: ref }, { 'guest.email': ref }],
  }).populate('room', 'roomNumber roomType').populate('property', 'name');
  if (!booking) return res.status(404).json({ success: false, message: 'Booking not found' });
  res.json({ success: true, data: { booking } });
});

/**
 * @swagger
 * /guest/booking:
 *   post:
 *     tags: [Guest]
 *     summary: Create a new booking as a guest (no auth required)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [property, room, guest, checkIn, checkOut, numberOfGuests, roomType]
 *             properties:
 *               property:
 *                 type: string
 *               room:
 *                 type: string
 *               guest:
 *                 type: object
 *                 properties:
 *                   name:
 *                     type: string
 *                   email:
 *                     type: string
 *                   phone:
 *                     type: string
 *               checkIn:
 *                 type: string
 *                 format: date
 *               checkOut:
 *                 type: string
 *                 format: date
 *               numberOfGuests:
 *                 type: integer
 *               roomType:
 *                 type: string
 *     responses:
 *       201:
 *         description: Booking created successfully
 *       400:
 *         description: Validation error
 *       409:
 *         description: Room already booked for these dates
 */
router.post('/guest/booking', validate(guestBookingSchema), async (req, res, next) => {
  try {
    const bookingService = await import('../services/booking.service.js');
    const { sendSuccess } = await import('../utils/response.util.js');
    const booking = await bookingService.createGuestBooking(req.body);
    return sendSuccess(res, { statusCode: 201, message: 'Booking created successfully', data: { booking } });
  } catch (err) { return next(err); }
});

/**
 * @swagger
 * /guest/bookings:
 *   get:
 *     tags: [Guest]
 *     summary: Get all bookings for a guest by email
 *     parameters:
 *       - in: query
 *         name: email
 *         required: true
 *         schema:
 *           type: string
 *         description: Guest email address
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: List of guest bookings
 *       400:
 *         description: Email required
 */
router.get('/guest/bookings', async (req, res, next) => {
  try {
    const Booking = (await import('../models/booking.model.js')).default;
    const { sendSuccess } = await import('../utils/response.util.js');
    const { email, page = 1, limit = 20 } = req.query;
    if (!email) return res.status(400).json({ success: false, message: 'Email required' });

    const query = { 'guest.email': email.toLowerCase() };
    const total = await Booking.countDocuments(query);
    const bookings = await Booking.find(query)
      .populate('room', 'roomNumber roomType name')
      .populate('property', 'name')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    return sendSuccess(res, { data: { bookings, total, page: parseInt(page), limit: parseInt(limit) } });
  } catch (err) { return next(err); }
});

/**
 * @swagger
 * /guest/payment:
 *   post:
 *     tags: [Guest]
 *     summary: Make a payment for a guest booking (requires booking reference and guest email)
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [bookingRef, email, amount]
 *             properties:
 *               bookingRef:
 *                 type: string
 *                 description: Booking ID
 *               email:
 *                 type: string
 *                 description: Guest email for verification
 *               amount:
 *                 type: number
 *               method:
 *                 type: string
 *                 enum: [card, online]
 *     responses:
 *       201:
 *         description: Payment recorded
 *       400:
 *         description: Validation error
 *       404:
 *         description: Booking not found or email mismatch
 */
router.post('/guest/payment', async (req, res, next) => {
  try {
    const Booking = (await import('../models/booking.model.js')).default;
    const Payment = (await import('../models/payment.model.js')).default;
    const { sendSuccess } = await import('../utils/response.util.js');
    const { logAudit } = await import('../utils/audit.util.js');
    const { generatePaymentCode } = await import('../utils/codeGenerator.js');

    const { bookingRef, email, amount, method = 'online' } = req.body;
    if (!bookingRef || !email || !amount) {
      return res.status(400).json({ success: false, message: 'bookingRef, email, and amount are required' });
    }

    const booking = await Booking.findOne({ _id: bookingRef, 'guest.email': email.toLowerCase() });
    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found or email does not match' });

    const outstanding = booking.pricing.totalAmount - booking.amountPaid;
    if (amount > outstanding + 1) {
      return res.status(400).json({ success: false, message: `Payment amount (LKR ${amount}) exceeds outstanding balance (LKR ${outstanding})` });
    }

    const existingPayment = await Payment.findOne({
      booking: booking._id,
      status: 'completed',
      amount,
      method,
    });
    if (existingPayment) {
      return res.status(409).json({ success: false, message: 'A payment with the same amount and method already exists for this booking' });
    }

    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();

    const payment = await Payment.create({
      code: await generatePaymentCode(),
      property: booking.property,
      booking: booking._id,
      amount,
      method,
      type: 'partial',
      status: 'completed',
      paidAt: new Date(),
      invoiceNumber: `INV-${timestamp}-${random}`,
    });

    // Update booking payment status
    const totalPaid = await Payment.aggregate([
      { $match: { booking: booking._id, status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]);
    const amountPaid = totalPaid.length > 0 ? totalPaid[0].total : 0;
    const paymentStatus = amountPaid >= booking.pricing.totalAmount ? 'paid' : amountPaid > 0 ? 'partial' : 'pending';
    await Booking.findByIdAndUpdate(booking._id, { amountPaid, paymentStatus });

    await logAudit({ action: 'payment', entity: 'Payment', entityId: payment._id, description: `Guest payment of ${amount} for booking ${bookingRef}`, ip: req.ip });

    return sendSuccess(res, { statusCode: 201, message: 'Payment recorded successfully', data: { payment } });
  } catch (err) { return next(err); }
});

// ===================== ANY AUTHENTICATED USER =====================
/**
 * @swagger
 * /auth/logout:
 *   post:
 *     tags: [Auth]
 *     summary: Logout current session
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Logged out successfully
 *       401:
 *         description: Unauthorized
 */
router.post('/auth/logout', authenticate, authController.logout);

/**
 * @swagger
 * /users/me:
 *   get:
 *     tags: [Users]
 *     summary: Get current user profile
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User profile retrieved
 *       401:
 *         description: Unauthorized
 */
router.get('/users/me', authenticate, userController.getProfile);

/**
 * @swagger
 * /users/me:
 *   patch:
 *     tags: [Users]
 *     summary: Update current user profile
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               email:
 *                 type: string
 *     responses:
 *       200:
 *         description: Profile updated
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 */
router.patch('/users/me', authenticate, validate(updateProfileSchema), userController.updateProfile);

/**
 * @swagger
 * /users/me:
 *   delete:
 *     tags: [Users]
 *     summary: Delete current user account
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Account deleted
 *       401:
 *         description: Unauthorized
 */
router.delete('/users/me', authenticate, userController.deleteAccount);

/**
 * @swagger
 * /auth/change-password:
 *   post:
 *     tags: [Auth]
 *     summary: Change password for authenticated user
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [currentPassword, newPassword]
 *             properties:
 *               currentPassword:
 *                 type: string
 *               newPassword:
 *                 type: string
 *     responses:
 *       200:
 *         description: Password changed
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 */
router.post('/auth/change-password', authenticate, validate(changePasswordSchema), passwordController.changePassword);

/**
 * @swagger
 * /notifications:
 *   get:
 *     tags: [Notifications]
 *     summary: Get all notifications for current user
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Notifications retrieved
 *       401:
 *         description: Unauthorized
 */
router.get('/notifications', authenticate, notificationController.getNotifications);

/**
 * @swagger
 * /notifications/unread:
 *   get:
 *     tags: [Notifications]
 *     summary: Get unread notification count
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Unread count retrieved
 *       401:
 *         description: Unauthorized
 */
router.get('/notifications/unread', authenticate, notificationController.getUnreadCount);

/**
 * @swagger
 * /notifications/{id}/read:
 *   patch:
 *     tags: [Notifications]
 *     summary: Mark notification as read
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Notification marked as read
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Notification not found
 */
router.patch('/notifications/:id/read', authenticate, notificationController.markAsRead);

/**
 * @swagger
 * /notifications/read-all:
 *   patch:
 *     tags: [Notifications]
 *     summary: Mark all notifications as read
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: All notifications marked as read
 *       401:
 *         description: Unauthorized
 */
router.patch('/notifications/read-all', authenticate, notificationController.markAllAsRead);

/**
 * @swagger
 * /upload/single:
 *   post:
 *     tags: [Upload]
 *     summary: Upload a single file
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               file:
 *                 type: string
 *                 format: binary
 *     responses:
 *       200:
 *         description: File uploaded
 *       400:
 *         description: No file uploaded
 *       401:
 *         description: Unauthorized
 */
router.post('/upload/single', authenticate, uploadSingle('file'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
    const result = await uploadFileToImgBB(req.file);
    res.json({
      success: true,
      data: {
        url: result.url,
        displayUrl: result.displayUrl,
        deleteUrl: result.deleteUrl,
        width: result.width,
        height: result.height,
        size: result.size,
        originalName: req.file.originalname,
        mimetype: req.file.mimetype,
      },
    });
  } catch (err) {
    return next(err);
  }
});

/**
 * @swagger
 * /upload/multiple:
 *   post:
 *     tags: [Upload]
 *     summary: Upload multiple files (max 5)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         multipart/form-data:
 *           schema:
 *             type: object
 *             properties:
 *               files:
 *                 type: array
 *                 items:
 *                   type: string
 *                   format: binary
 *     responses:
 *       200:
 *         description: Files uploaded
 *       400:
 *         description: No files uploaded
 *       401:
 *         description: Unauthorized
 */
router.post('/upload/multiple', authenticate, uploadMultiple('files', 5), async (req, res, next) => {
  try {
    if (!req.files || req.files.length === 0) return res.status(400).json({ success: false, message: 'No files uploaded' });
    const results = await uploadMultipleToImgBB(req.files);
    const files = results.map((r, i) => ({
      url: r.url,
      displayUrl: r.displayUrl,
      deleteUrl: r.deleteUrl,
      width: r.width,
      height: r.height,
      size: r.size,
      originalName: req.files[i].originalname,
      mimetype: req.files[i].mimetype,
    }));
    res.json({ success: true, data: { files } });
  } catch (err) {
    return next(err);
  }
});

/**
 * @swagger
 * /properties/{propertyId}/rooms/available:
 *   get:
 *     tags: [Rooms]
 *     summary: Get available rooms for a property
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Available rooms retrieved
 *       404:
 *         description: Property not found
 */
router.get('/properties/:propertyId/rooms/available', roomController.getAvailableRooms);

// ===================== MANAGER & ADMIN =====================
/**
 * @swagger
 * /properties:
 *   post:
 *     tags: [Properties]
 *     summary: Create a new property (Admin only)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               address:
 *                 type: string
 *               description:
 *                 type: string
 *     responses:
 *       201:
 *         description: Property created
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin only
 */
router.post('/properties', authenticate, authorize(...managerRoles), validate(createPropertySchema), propertyController.createProperty);

/**
 * @swagger
 * /properties:
 *   get:
 *     tags: [Properties]
 *     summary: Get all properties
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Properties retrieved
 *       401:
 *         description: Unauthorized
 */
router.get('/properties', authenticate, propertyController.getProperties);

/**
 * @swagger
 * /properties/{id}:
 *   get:
 *     tags: [Properties]
 *     summary: Get property by ID
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Property retrieved
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Property not found
 */
router.get('/properties/:id', authenticate, propertyController.getPropertyById);

/**
 * @swagger
 * /properties/{id}:
 *   patch:
 *     tags: [Properties]
 *     summary: Update a property (Admin only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               name:
 *                 type: string
 *               address:
 *                 type: string
 *               description:
 *                 type: string
 *     responses:
 *       200:
 *         description: Property updated
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin only
 */
router.patch('/properties/:id', authenticate, authorize(...managerRoles), propertyController.preserveVersion, validate(updatePropertySchema), propertyController.updateProperty);

/**
 * @swagger
 * /properties/{id}:
 *   delete:
 *     tags: [Properties]
 *     summary: Delete a property (Admin only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Property deleted
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin only
 *       404:
 *         description: Property not found
 */
router.delete('/properties/:id', authenticate, authorize(...managerRoles), propertyController.deleteProperty);

/**
 * @swagger
 * /properties/{id}/stats:
 *   get:
 *     tags: [Properties]
 *     summary: Get property statistics
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Property stats retrieved
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Property not found
 */
router.get('/properties/:id/stats', authenticate, propertyController.getPropertyStats);

router.get('/dashboard/stats', authenticate, async (req, res, next) => {
  try {
    const Property = (await import('../models/property.model.js')).default;
    const Room = (await import('../models/room.model.js')).default;
    const Booking = (await import('../models/booking.model.js')).default;
    const Task = (await import('../models/task.model.js')).default;
    const Payment = (await import('../models/payment.model.js')).default;
    const Feedback = (await import('../models/feedback.model.js')).default;

    const properties = await Property.find({ isActive: true });
    const propertyIds = properties.map(p => p._id);

    const [
      totalRooms, availableRooms, bookedRooms, occupiedRooms, maintenanceRooms,
      totalBookings, activeBookings, confirmedBookings, checkedInBookings, checkedOutBookings, cancelledBookings,
      totalTasks, openTasks, inProgressTasks, completedTasks, overdueTasks,
      paymentAgg, todayPaymentAgg,
      feedbackStats,
    ] = await Promise.all([
      Room.countDocuments({ property: { $in: propertyIds }, isActive: true }),
      Room.countDocuments({ property: { $in: propertyIds }, status: 'available', isActive: true }),
      Room.countDocuments({ property: { $in: propertyIds }, status: 'booked' }),
      Room.countDocuments({ property: { $in: propertyIds }, status: 'occupied' }),
      Room.countDocuments({ property: { $in: propertyIds }, status: 'maintenance' }),
      Booking.countDocuments({ property: { $in: propertyIds } }),
      Booking.countDocuments({ property: { $in: propertyIds }, bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] } }),
      Booking.countDocuments({ property: { $in: propertyIds }, bookingStatus: 'confirmed' }),
      Booking.countDocuments({ property: { $in: propertyIds }, bookingStatus: 'checked-in' }),
      Booking.countDocuments({ property: { $in: propertyIds }, bookingStatus: 'checked-out' }),
      Booking.countDocuments({ property: { $in: propertyIds }, bookingStatus: 'cancelled' }),
      Task.countDocuments({ property: { $in: propertyIds } }),
      Task.countDocuments({ property: { $in: propertyIds }, status: 'open' }),
      Task.countDocuments({ property: { $in: propertyIds }, status: 'in-progress' }),
      Task.countDocuments({ property: { $in: propertyIds }, status: 'completed' }),
      Task.countDocuments({ property: { $in: propertyIds }, status: { $in: ['open', 'in-progress'] }, dueDate: { $lt: new Date() } }),
      Payment.aggregate([
        { $match: { property: { $in: propertyIds }, status: 'completed', type: { $ne: 'refund' } } },
        { $group: { _id: null, total: { $sum: '$amount' } } },
      ]),
      Payment.aggregate([
        { $match: { property: { $in: propertyIds }, status: 'completed', type: { $ne: 'refund' }, paidAt: { $gte: new Date(new Date().setHours(0,0,0,0)) } } },
        { $group: { _id: null, total: { $sum: '$amount' } } },
      ]),
      Feedback.aggregate([
        { $match: { property: { $in: propertyIds } } },
        { $group: { _id: null, avgRating: { $avg: '$rating' }, count: { $sum: 1 } } },
      ]),
    ]);

    const totalRevenue = paymentAgg.length > 0 ? paymentAgg[0].total : 0;
    const todayRevenue = todayPaymentAgg.length > 0 ? todayPaymentAgg[0].total : 0;
    const avgRating = feedbackStats.length > 0 ? parseFloat(feedbackStats[0].avgRating?.toFixed(1) || '0') : 0;
    const totalReviews = feedbackStats.length > 0 ? feedbackStats[0].count : 0;

    const occupancyRate = totalRooms > 0 ? (((bookedRooms + occupiedRooms) / totalRooms) * 100).toFixed(1) : '0.0';

    const propertyPerformance = await Promise.all(properties.map(async (p) => {
      const pRooms = await Room.countDocuments({ property: p._id, isActive: true });
      const pBooked = await Room.countDocuments({ property: p._id, status: { $in: ['booked', 'occupied'] } });
      const pRevenue = await Payment.aggregate([
        { $match: { property: p._id, status: 'completed', type: { $ne: 'refund' } } },
        { $group: { _id: null, total: { $sum: '$amount' } } },
      ]);
      const pTasks = await Task.countDocuments({ property: p._id, status: { $in: ['open', 'in-progress'] } });
      return {
        id: p._id, name: p.name, code: p.code,
        rooms: pRooms,
        occupancy: pRooms > 0 ? parseFloat(((pBooked / pRooms) * 100).toFixed(1)) : 0,
        revenue: pRevenue.length > 0 ? pRevenue[0].total : 0,
        openTasks: pTasks,
      };
    }));

    const monthlyRevenue = await Payment.aggregate([
      { $match: { property: { $in: propertyIds }, status: 'completed', type: { $ne: 'refund' }, paidAt: { $gte: new Date(Date.now() - 6 * 30 * 24 * 60 * 60 * 1000) } } },
      { $group: { _id: { month: { $month: '$paidAt' }, year: { $year: '$paidAt' } }, total: { $sum: '$amount' } } },
      { $sort: { '_id.year': 1, '_id.month': 1 } },
    ]);

    return res.json({
      success: true,
      data: {
        properties: properties.length,
        totalRooms, availableRooms, bookedRooms, occupiedRooms, maintenanceRooms,
        occupancyRate: parseFloat(occupancyRate),
        totalBookings, activeBookings, confirmedBookings, checkedInBookings, checkedOutBookings, cancelledBookings,
        totalTasks, openTasks, inProgressTasks, completedTasks, overdueTasks,
        totalRevenue, todayRevenue,
        avgRating, totalReviews,
        propertyPerformance,
        monthlyRevenue,
      },
    });
  } catch (err) { return next(err); }
});

/**
 * @swagger
 * /properties/{propertyId}/rooms:
 *   post:
 *     tags: [Rooms]
 *     summary: Create a room in a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               roomNumber:
 *                 type: string
 *               roomType:
 *                 type: string
 *               price:
 *                 type: number
 *     responses:
 *       201:
 *         description: Room created
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.post('/properties/:propertyId/rooms', authenticate, authorize(...managerRoles), validate(createRoomSchema), roomController.createRoom);

router.post('/properties/:propertyId/rooms/bulk', authenticate, authorize(...managerRoles), async (req, res, next) => {
  try {
    const Room = (await import('../models/room.model.js')).default;
    const Property = (await import('../models/property.model.js')).default;
    const { generateRoomCode } = await import('../utils/codeGenerator.js');
    const { logAudit } = await import('../utils/audit.util.js');


    const property = await Property.findById(req.params.propertyId);
    if (!property) return res.status(404).json({ success: false, message: 'Property not found' });
    if (property.owner.toString() !== req.user.sub) {
      return res.status(403).json({ success: false, message: 'You can only add rooms to your own properties' });
    }

    const { roomType, basePrice, capacity, floor, amenities, images, description, count } = req.body;
    if (!roomType || !basePrice || !capacity || !count || count < 1 || count > 100) {
      return res.status(400).json({ success: false, message: 'roomType, basePrice, capacity, count (1-100) are required' });
    }

    const lastRoom = await Room.findOne({ property: req.params.propertyId })
      .sort({ roomNumber: -1 })
      .collation({ locale: 'en', numericOrdering: true });
    
    let startSeq = 1;
    let prefix = 'R';
    if (lastRoom && lastRoom.roomNumber) {
      const numMatch = lastRoom.roomNumber.match(/\d+/);
      if (numMatch) {
        startSeq = parseInt(numMatch[0], 10) + 1;
        // Keep the same non-digit prefix if any (e.g. "R" or "RM")
        prefix = lastRoom.roomNumber.replace(/\d+/, '');
      }
    }

    const created = [];

    for (let i = 0; i < count; i++) {
      const seq = startSeq + i;
      const code = await generateRoomCode();
      const roomNumber = `${prefix}${String(seq).padStart(3, '0')}`;
      const typeCapitalized = roomType.charAt(0).toUpperCase() + roomType.slice(1);

      const room = await Room.create({
        code,
        property: req.params.propertyId,
        roomNumber,
        roomType,
        name: `${typeCapitalized} Room ${seq}`,
        capacity: parseInt(capacity) || 2,
        basePrice: parseFloat(basePrice) || 0,
        floor: (floor !== undefined && floor !== null && floor !== '') ? parseInt(floor) : Math.ceil(seq / 5),
        amenities: amenities || [],
        images: images || [],
        description: description || '',
        status: 'available',
        isActive: true,
        createdBy: req.user.sub,
      });
      created.push(room);
    }

    const activeRoomsCount = await Room.countDocuments({ property: req.params.propertyId, isActive: true });
    await Property.findByIdAndUpdate(req.params.propertyId, { $set: { totalRooms: activeRoomsCount } });
    await logAudit({ user: req.user.sub, action: 'bulk-create', entity: 'Room', entityId: req.params.propertyId, description: `Bulk created ${count} rooms`, ip: req.ip });

    return res.status(201).json({ success: true, data: { rooms: created, count: created.length } });
  } catch (err) { return next(err); }
});

/**
 * @swagger
 * /properties/{propertyId}/rooms:
 *   get:
 *     tags: [Rooms]
 *     summary: Get all rooms for a property
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Rooms retrieved
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Property not found
 */
router.get('/properties/:propertyId/rooms', authenticate, roomController.getRooms);

/**
 * @swagger
 * /rooms/{id}:
 *   get:
 *     tags: [Rooms]
 *     summary: Get room by ID
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Room retrieved
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Room not found
 */
router.get('/rooms/:id', authenticate, roomController.getRoomById);

/**
 * @swagger
 * /rooms/{id}:
 *   patch:
 *     tags: [Rooms]
 *     summary: Update a room (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               roomNumber:
 *                 type: string
 *               roomType:
 *                 type: string
 *               price:
 *                 type: number
 *     responses:
 *       200:
 *         description: Room updated
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 *       404:
 *         description: Room not found
 */
router.patch('/rooms/:id', authenticate, authorize(...managerRoles), validate(updateRoomSchema), roomController.updateRoom);

/**
 * @swagger
 * /rooms/{id}:
 *   delete:
 *     tags: [Rooms]
 *     summary: Delete a room (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Room deleted
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 *       404:
 *         description: Room not found
 */
router.delete('/rooms/:id', authenticate, authorize(...managerRoles), roomController.deleteRoom);

/**
 * @swagger
 * /bookings:
 *   post:
 *     tags: [Bookings]
 *     summary: Create a new booking (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               property:
 *                 type: string
 *               room:
 *                 type: string
 *               guest:
 *                 type: object
 *               checkIn:
 *                 type: string
 *                 format: date
 *               checkOut:
 *                 type: string
 *                 format: date
 *     responses:
 *       201:
 *         description: Booking created
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.post('/bookings', authenticate, authorize(...managerRoles), validate(createBookingSchema), bookingController.createBooking);

/**
 * @swagger
 * /properties/{propertyId}/bookings:
 *   get:
 *     tags: [Bookings]
 *     summary: Get all bookings for a property
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Bookings retrieved
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Property not found
 */
router.get('/properties/:propertyId/bookings', authenticate, bookingController.getBookings);

/**
 * @swagger
 * /bookings:
 *   get:
 *     tags: [Bookings]
 *     summary: Get all bookings across all user properties
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *       - in: query
 *         name: status
 *         schema:
 *           type: string
 *       - in: query
 *         name: search
 *         schema:
 *           type: string
 *       - in: query
 *         name: propertyId
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Bookings retrieved
 *       401:
 *         description: Unauthorized
 */
router.get('/bookings', authenticate, bookingController.getAllBookings);

/**
 * @swagger
 * /bookings/{id}:
 *   get:
 *     tags: [Bookings]
 *     summary: Get booking by ID
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Booking retrieved
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Booking not found
 */
router.get('/bookings/:id', authenticate, bookingController.getBookingById);

/**
 * @swagger
 * /bookings/{id}:
 *   patch:
 *     tags: [Bookings]
 *     summary: Update a booking (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               checkIn:
 *                 type: string
 *                 format: date
 *               checkOut:
 *                 type: string
 *                 format: date
 *               status:
 *                 type: string
 *     responses:
 *       200:
 *         description: Booking updated
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 *       404:
 *         description: Booking not found
 */
router.patch('/bookings/:id', authenticate, authorize(...managerRoles), validate(updateBookingSchema), bookingController.updateBooking);

/**
 * @swagger
 * /bookings/{id}/cancel:
 *   patch:
 *     tags: [Bookings]
 *     summary: Cancel a booking (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Booking cancelled
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 *       404:
 *         description: Booking not found
 */
router.patch('/bookings/:id/cancel', authenticate, authorize(...managerRoles), bookingController.cancelBooking);

/**
 * @swagger
 * /bookings/{id}:
 *   delete:
 *     tags: [Bookings]
 *     summary: Delete a booking (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Booking deleted
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Booking not found
 */
router.delete('/bookings/:id', authenticate, authorize(...managerRoles), bookingController.deleteBooking);

/**
 * @swagger
 * /bookings/{id}/check-in:
 *   patch:
 *     tags: [Bookings]
 *     summary: Check in a booking (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Guest checked in
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 *       404:
 *         description: Booking not found
 */
router.patch('/bookings/:id/check-in', authenticate, authorize(...managerRoles), bookingController.checkIn);

/**
 * @swagger
 * /bookings/{id}/check-out:
 *   patch:
 *     tags: [Bookings]
 *     summary: Check out a booking (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Guest checked out
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 *       404:
 *         description: Booking not found
 */
router.patch('/bookings/:id/check-out', authenticate, authorize(...managerRoles), bookingController.checkOut);

/**
 * @swagger
 * /properties/{propertyId}/bookings/calendar:
 *   get:
 *     tags: [Bookings]
 *     summary: Get bookings calendar view
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Calendar bookings retrieved
 *       401:
 *         description: Unauthorized
 */
router.get('/properties/:propertyId/bookings/calendar', authenticate, bookingController.getCalendarBookings);

/**
 * @swagger
 * /properties/{propertyId}/bookings/stats:
 *   get:
 *     tags: [Bookings]
 *     summary: Get booking statistics for a property
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Booking stats retrieved
 *       401:
 *         description: Unauthorized
 */
router.get('/properties/:propertyId/bookings/stats', authenticate, bookingController.getBookingStats);

/**
 * @swagger
 * /tasks:
 *   post:
 *     tags: [Tasks]
 *     summary: Create a new task (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *               property:
 *                 type: string
 *               assignedTo:
 *                 type: string
 *               priority:
 *                 type: string
 *                 enum: [low, medium, high]
 *     responses:
 *       201:
 *         description: Task created
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.post('/tasks', authenticate, authorize(...managerRoles), validate(createTaskSchema), taskController.createTask);

/**
 * @swagger
 * /properties/{propertyId}/tasks:
 *   get:
 *     tags: [Tasks]
 *     summary: Get all tasks for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Tasks retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/tasks', authenticate, authorize(...managerRoles), taskController.getTasks);

/**
 * @swagger
 * /tasks/my:
 *   get:
 *     tags: [Tasks]
 *     summary: Get tasks assigned to current user
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User tasks retrieved
 *       401:
 *         description: Unauthorized
 */
router.get('/tasks/my', authenticate, taskController.getMyTasks);

/**
 * @swagger
 * /tasks/{id}:
 *   get:
 *     tags: [Tasks]
 *     summary: Get task by ID
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Task retrieved
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Task not found
 */
router.get('/tasks/:id', authenticate, taskController.getTaskById);

/**
 * @swagger
 * /tasks/{id}:
 *   delete:
 *     summary: Delete a task
 *     tags: [Tasks]
 *     security:
 *       - bearerAuth: []
 */
router.delete('/tasks/:id', authenticate, authorize(...managerRoles), taskController.deleteTask);

/**
 * @swagger
 * /tasks/{id}:
 *   patch:
 *     tags: [Tasks]
 *     summary: Update a task (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *               status:
 *                 type: string
 *               priority:
 *                 type: string
 *     responses:
 *       200:
 *         description: Task updated
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 *       404:
 *         description: Task not found
 */
router.patch('/tasks/:id', authenticate, authorize(...staffRoles), validate(updateTaskSchema), taskController.updateTask);

/**
 * @swagger
 * /tasks/{id}/complete:
 *   patch:
 *     tags: [Tasks]
 *     summary: Mark task as complete
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Task completed
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Task not found
 */
router.patch('/tasks/:id/complete', authenticate, authorize(...staffRoles), validate(completeTaskSchema), taskController.completeTask);

/**
 * @swagger
 * /tasks/{id}/subtasks/{index}:
 *   patch:
 *     tags: [Tasks]
 *     summary: Toggle subtask completion status
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: index
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Subtask toggled
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Task not found
 */
router.patch('/tasks/:id/subtasks/:index', authenticate, authorize(...staffRoles), taskController.toggleSubtask);

/**
 * @swagger
 * /tasks/{id}/checklist/{index}:
 *   patch:
 *     tags: [Tasks]
 *     summary: Toggle checklist item completion status
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *       - in: path
 *         name: index
 *         required: true
 *         schema:
 *           type: integer
 *     responses:
 *       200:
 *         description: Checklist item toggled
 *       401:
 *         description: Unauthorized
 *       404:
 *         description: Task not found
 */
router.patch('/tasks/:id/checklist/:index', authenticate, authorize(...staffRoles), taskController.toggleChecklist);

/**
 * @swagger
 * /properties/{propertyId}/tasks/stats:
 *   get:
 *     tags: [Tasks]
 *     summary: Get task statistics for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Task stats retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/tasks/stats', authenticate, authorize(...managerRoles), taskController.getTaskStats);

/**
 * @swagger
 * /payments:
 *   post:
 *     tags: [Payments]
 *     summary: Create a new payment record (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               booking:
 *                 type: string
 *               amount:
 *                 type: number
 *               method:
 *                 type: string
 *     responses:
 *       201:
 *         description: Payment created
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.post('/payments', authenticate, authorize(...managerRoles), validate(createPaymentSchema), paymentController.createPayment);

/**
 * @swagger
 * /properties/{propertyId}/payments:
 *   get:
 *     tags: [Payments]
 *     summary: Get all payments for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Payments retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/payments', authenticate, authorize(...managerRoles), paymentController.getPayments);

/**
 * @swagger
 * /payments/{id}:
 *   get:
 *     tags: [Payments]
 *     summary: Get payment by ID (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Payment retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 *       404:
 *         description: Payment not found
 */
router.get('/payments/:id', authenticate, authorize(...managerRoles), paymentController.getPaymentById);

/**
 * @swagger
 * /payments/{id}/status:
 *   patch:
 *     tags: [Payments]
 *     summary: Update payment status (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               status:
 *                 type: string
 *                 enum: [pending, completed, failed, refunded]
 *     responses:
 *       200:
 *         description: Payment status updated
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 *       404:
 *         description: Payment not found
 */
router.patch('/payments/:id/status', authenticate, authorize(...managerRoles), paymentController.updatePaymentStatus);

/**
 * @swagger
 * /properties/{propertyId}/payments/stats:
 *   get:
 *     tags: [Payments]
 *     summary: Get payment statistics for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Payment stats retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/payments/stats', authenticate, authorize(...managerRoles), paymentController.getPaymentStats);

/**
 * @swagger
 * /properties/{propertyId}/feedback:
 *   get:
 *     tags: [Feedback]
 *     summary: Get all feedback for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Feedback retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/feedback', authenticate, authorize(...managerRoles), feedbackController.getFeedback);

/**
 * @swagger
 * /properties/{propertyId}/feedback/stats:
 *   get:
 *     tags: [Feedback]
 *     summary: Get feedback statistics for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Feedback stats retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/feedback/stats', authenticate, authorize(...managerRoles), feedbackController.getFeedbackStats);

/**
 * @swagger
 * /feedback/{id}/respond:
 *   patch:
 *     tags: [Feedback]
 *     summary: Respond to guest feedback (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               response:
 *                 type: string
 *     responses:
 *       200:
 *         description: Feedback response added
 *       400:
 *         description: Validation error
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 *       404:
 *         description: Feedback not found
 */
router.patch('/feedback/:id/respond', authenticate, authorize(...managerRoles), validate(respondFeedbackSchema), feedbackController.respondToFeedback);
router.patch('/feedback/:id/resolve', authenticate, authorize(...managerRoles), feedbackController.resolveFeedback);

router.patch('/feedback/:id', authenticate, authorize(...managerRoles), feedbackController.toggleFeedbackVisibility);


/**
 * @swagger
 * /properties/{propertyId}/analytics/revenue:
 *   get:
 *     tags: [Analytics]
 *     summary: Get revenue report for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Revenue report retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/analytics/revenue', authenticate, authorize(...managerRoles), analyticsController.getRevenueReport);

/**
 * @swagger
 * /properties/{propertyId}/analytics/occupancy:
 *   get:
 *     tags: [Analytics]
 *     summary: Get occupancy report for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Occupancy report retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/analytics/occupancy', authenticate, authorize(...managerRoles), analyticsController.getOccupancyReport);

/**
 * @swagger
 * /properties/{propertyId}/analytics/trends:
 *   get:
 *     tags: [Analytics]
 *     summary: Get booking trends for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Booking trends retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/analytics/trends', authenticate, authorize(...managerRoles), analyticsController.getBookingTrends);

/**
 * @swagger
 * /properties/{propertyId}/analytics/tasks:
 *   get:
 *     tags: [Analytics]
 *     summary: Get task performance for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Task performance retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/analytics/tasks', authenticate, authorize(...managerRoles), analyticsController.getTaskPerformance);

/**
 * @swagger
 * /properties/{propertyId}/analytics/rooms:
 *   get:
 *     tags: [Analytics]
 *     summary: Get room type performance for a property (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Room performance retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/analytics/rooms', authenticate, authorize(...managerRoles), analyticsController.getRoomTypePerformance);

// CSV Exports - admin/manager
/**
 * @swagger
 * /properties/{propertyId}/export/bookings:
 *   get:
 *     tags: [Analytics]
 *     summary: Export bookings as CSV (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: CSV file downloaded
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/export/bookings', authenticate, authorize(...managerRoles), analyticsController.exportBookingsCsv);

/**
 * @swagger
 * /properties/{propertyId}/export/payments:
 *   get:
 *     tags: [Analytics]
 *     summary: Export payments as CSV (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: CSV file downloaded
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/export/payments', authenticate, authorize(...managerRoles), analyticsController.exportPaymentsCsv);

/**
 * @swagger
 * /properties/{propertyId}/export/rooms:
 *   get:
 *     tags: [Analytics]
 *     summary: Export rooms as CSV (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: CSV file downloaded
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/export/rooms', authenticate, authorize(...managerRoles), analyticsController.exportRoomsCsv);

/**
 * @swagger
 * /properties/{propertyId}/export/tasks:
 *   get:
 *     tags: [Analytics]
 *     summary: Export tasks as CSV (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: CSV file downloaded
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/export/tasks', authenticate, authorize(...managerRoles), analyticsController.exportTasksCsv);

// PDF Exports - admin/manager
/**
 * @swagger
 * /properties/{propertyId}/export/bookings/pdf:
 *   get:
 *     tags: [Analytics]
 *     summary: Export bookings as PDF (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: PDF file downloaded
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/export/bookings/pdf', authenticate, authorize(...managerRoles), exportController.exportBookingsPdf);

/**
 * @swagger
 * /properties/{propertyId}/export/payments/pdf:
 *   get:
 *     tags: [Analytics]
 *     summary: Export payments as PDF (Admin/Manager only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: PDF file downloaded
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin/Manager only
 */
router.get('/properties/:propertyId/export/payments/pdf', authenticate, authorize(...managerRoles), exportController.exportPaymentsPdf);

/**
 * @swagger
 * /analytics/consolidated:
 *   get:
 *     tags: [Analytics]
 *     summary: Get consolidated analytics report (Admin only)
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Consolidated report retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin only
 */
router.get('/analytics/consolidated', authenticate, authorize('admin'), advancedController.getConsolidatedReport);

/**
 * @swagger
 * /analytics/calendar:
 *   get:
 *     tags: [Analytics]
 *     summary: Get consolidated calendar view (Admin only)
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Consolidated calendar retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin only
 */
router.get('/analytics/calendar', authenticate, authorize('admin'), advancedController.getConsolidatedCalendar);

/**
 * @swagger
 * /properties/{propertyId}/analytics/pricing:
 *   get:
 *     tags: [Analytics]
 *     summary: Get AI pricing suggestions for a property (Admin only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Pricing suggestions retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin only
 */
router.get('/properties/:propertyId/analytics/pricing', authenticate, authorize('admin'), advancedController.getAIPricingSuggestions);

/**
 * @swagger
 * /properties/{propertyId}/analytics/forecast:
 *   get:
 *     tags: [Analytics]
 *     summary: Get demand forecast for a property (Admin only)
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: propertyId
 *         required: true
 *         schema:
 *           type: string
 *     responses:
 *       200:
 *         description: Demand forecast retrieved
 *       401:
 *         description: Unauthorized
 *       403:
 *         description: Admin only
 */
router.get('/properties/:propertyId/analytics/forecast', authenticate, authorize('admin'), advancedController.getDemandForecast);

// ===================== ADMIN ONLY =====================
router.get('/admin/users', authenticate, authorize('admin'), userController.getAllUsers);
router.post('/admin/users', authenticate, authorize('admin'), validate(createUserSchema), userController.createUser);
router.get('/admin/users/:id', authenticate, authorize('admin'), userController.getUserById);
router.patch('/admin/users/:id', authenticate, authorize('admin'), validate(updateUserSchema), userController.updateUser);
router.patch('/admin/users/:id/role', authenticate, authorize('admin'), validate(updateUserRoleSchema), userController.updateUserRole);
router.patch('/admin/users/:id/status', authenticate, authorize('admin'), validate(toggleUserStatusSchema), userController.toggleUserStatus);

// Audit Logs - admin only
router.get('/admin/audit-logs', authenticate, authorize('admin'), auditController.getAuditLogs);

export default router;

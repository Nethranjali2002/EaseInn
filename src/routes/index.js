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
import {
  registerSchema,
  loginSchema,
  refreshSchema,
  updateProfileSchema,
  forgotPasswordSchema,
  resetPasswordSchema,
  changePasswordSchema,
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
  createPaymentSchema,
  respondFeedbackSchema,
  submitReviewSchema,
  guestBookingSchema,
} from '../validators/domain.validator.js';

const router = Router();
const managerRoles = ['admin', 'manager'];

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

    const { bookingRef, email, amount, method = 'online' } = req.body;
    if (!bookingRef || !email || !amount) {
      return res.status(400).json({ success: false, message: 'bookingRef, email, and amount are required' });
    }

    const booking = await Booking.findOne({ _id: bookingRef, 'guest.email': email.toLowerCase() });
    if (!booking) return res.status(404).json({ success: false, message: 'Booking not found or email does not match' });

    const timestamp = Date.now().toString(36).toUpperCase();
    const random = Math.random().toString(36).substring(2, 6).toUpperCase();

    const payment = await Payment.create({
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
router.post('/upload/single', authenticate, uploadSingle('file'), (req, res) => {
  if (!req.file) return res.status(400).json({ success: false, message: 'No file uploaded' });
  res.json({ success: true, data: { filename: req.file.filename, originalName: req.file.originalname, size: req.file.size, mimetype: req.file.mimetype, url: `/uploads/${req.file.mimetype.startsWith('image') ? 'images' : 'documents'}/${req.file.filename}` } });
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
router.post('/upload/multiple', authenticate, uploadMultiple('files', 5), (req, res) => {
  if (!req.files || req.files.length === 0) return res.status(400).json({ success: false, message: 'No files uploaded' });
  const files = req.files.map(f => ({ filename: f.filename, originalName: f.originalname, size: f.size, mimetype: f.mimetype, url: `/uploads/${f.mimetype.startsWith('image') ? 'images' : 'documents'}/${f.filename}` }));
  res.json({ success: true, data: { files } });
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
router.post('/properties', authenticate, authorize('admin'), validate(createPropertySchema), propertyController.createProperty);

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
router.patch('/properties/:id', authenticate, authorize('admin'), validate(updatePropertySchema), propertyController.updateProperty);

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
router.delete('/properties/:id', authenticate, authorize('admin'), propertyController.deleteProperty);

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
router.patch('/tasks/:id', authenticate, validate(updateTaskSchema), taskController.updateTask);

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
router.patch('/tasks/:id/complete', authenticate, taskController.completeTask);

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
router.patch('/tasks/:id/subtasks/:index', authenticate, taskController.toggleSubtask);

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
router.patch('/tasks/:id/checklist/:index', authenticate, taskController.toggleChecklist);

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
router.post('/admin/users', authenticate, authorize('admin'), userController.createUser);
router.get('/admin/users/:id', authenticate, authorize('admin'), userController.getUserById);
router.patch('/admin/users/:id/role', authenticate, authorize('admin'), userController.updateUserRole);
router.patch('/admin/users/:id/status', authenticate, authorize('admin'), userController.toggleUserStatus);

// Audit Logs - admin only
router.get('/admin/audit-logs', authenticate, authorize('admin'), auditController.getAuditLogs);

export default router;

import * as bookingService from '../services/booking.service.js';
import { sendSuccess } from '../utils/response.util.js';
import { logAudit } from '../utils/audit.util.js';
import { sendBookingConfirmationNotification, sendPaymentReceivedNotification } from '../utils/push.util.js';

export const createBooking = async (req, res, next) => {
  try {
    const booking = await bookingService.createBooking(req.body, req.user.sub);
    await logAudit({ user: req.user.sub, action: 'create', entity: 'Booking', entityId: booking._id, description: `Booking for ${booking.guest.name}`, ip: req.ip });
    await sendBookingConfirmationNotification(booking).catch(() => {});
    return sendSuccess(res, { statusCode: 201, message: 'Booking created', data: { booking } });
  } catch (err) { return next(err); }
};

export const getBookings = async (req, res, next) => {
  try {
    const { page, limit, status, search, startDate, endDate } = req.query;
    const result = await bookingService.getBookings(req.params.propertyId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, status, search, startDate, endDate });
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

export const getBookingById = async (req, res, next) => {
  try {
    const booking = await bookingService.getBookingById(req.params.id);
    return sendSuccess(res, { data: { booking } });
  } catch (err) { return next(err); }
};

export const updateBooking = async (req, res, next) => {
  try {
    const booking = await bookingService.updateBooking(req.params.id, req.body);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Booking', entityId: booking._id, description: `Updated booking for ${booking.guest.name}`, ip: req.ip });
    return sendSuccess(res, { message: 'Booking updated', data: { booking } });
  } catch (err) { return next(err); }
};

export const cancelBooking = async (req, res, next) => {
  try {
    const booking = await bookingService.cancelBooking(req.params.id, req.body.reason);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Booking', entityId: booking._id, description: `Cancelled booking for ${booking.guest.name}`, ip: req.ip });
    return sendSuccess(res, { message: 'Booking cancelled', data: { booking } });
  } catch (err) { return next(err); }
};

export const checkIn = async (req, res, next) => {
  try {
    const booking = await bookingService.checkIn(req.params.id);
    await logAudit({ user: req.user.sub, action: 'booking', entity: 'Booking', entityId: booking._id, description: `Checked in: ${booking.guest.name}`, ip: req.ip });
    return sendSuccess(res, { message: 'Guest checked in', data: { booking } });
  } catch (err) { return next(err); }
};

export const checkOut = async (req, res, next) => {
  try {
    const booking = await bookingService.checkOut(req.params.id);
    await logAudit({ user: req.user.sub, action: 'booking', entity: 'Booking', entityId: booking._id, description: `Checked out: ${booking.guest.name}`, ip: req.ip });
    return sendSuccess(res, { message: 'Guest checked out', data: { booking } });
  } catch (err) { return next(err); }
};

export const getCalendarBookings = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const bookings = await bookingService.getCalendarBookings(req.params.propertyId, startDate, endDate);
    return sendSuccess(res, { data: { bookings } });
  } catch (err) { return next(err); }
};

export const getBookingStats = async (req, res, next) => {
  try {
    const stats = await bookingService.getBookingStats(req.params.propertyId);
    return sendSuccess(res, { data: stats });
  } catch (err) { return next(err); }
};

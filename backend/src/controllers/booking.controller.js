import * as bookingService from '../services/booking.service.js'; // Imports the "Brain" that does the heavy lifting for bookings
import { sendSuccess } from '../utils/response.util.js'; // Imports our custom helper that formats JSON success messages perfectly
import { logAudit } from '../utils/audit.util.js'; // Imports our spy tool that silently records every action into the database
import { sendBookingConfirmationNotification, sendPaymentReceivedNotification } from '../utils/push.util.js'; // Imports automated push notifications

// ==========================================
// 1. CREATE BOOKING
// ==========================================
export const createBooking = async (req, res, next) => {
  try {
    // 1. Pass the raw booking data (req.body) and the User ID of the staff member creating it (req.user.sub) to the Service layer
    const booking = await bookingService.createBooking(req.body, req.user.sub);
    
    // 2. Silently record exactly who created this booking and when in the Audit Logs
    await logAudit({ user: req.user.sub, action: 'create', entity: 'Booking', entityId: booking._id, description: `Booking for ${booking.guest.name}`, ip: req.ip });
    
    // 3. Automatically trigger a push notification/email to the guest confirming their booking
    await sendBookingConfirmationNotification(booking).catch(() => {});
    
    // 4. Send a 201 Created success response back to the frontend with the shiny new booking object
    return sendSuccess(res, { statusCode: 201, message: 'Booking created', data: { booking } });
  } catch (err) { 
    // If the Service crashed (e.g. room is already taken), send error to the Global Handler
    return next(err); 
  }
};

// ==========================================
// 2. GET BOOKINGS (For a specific property)
// ==========================================
export const getBookings = async (req, res, next) => {
  try {
    // Extract pagination and filters from the URL (e.g., ?page=1&status=confirmed)
    const { page, limit, status, search, startDate, endDate } = req.query;
    
    // Pass the property ID and all filters to the Service to fetch the exact slice of data needed
    const result = await bookingService.getBookings(req.params.propertyId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, status, search, startDate, endDate });
    
    // Send the data (and total count for pagination) back to the frontend table
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

// ==========================================
// 3. GET ALL BOOKINGS (For Admins across ALL properties)
// ==========================================
export const getAllBookings = async (req, res, next) => {
  try {
    const { page, limit, status, search, startDate, endDate, propertyId } = req.query;
    // Pass the Admin's role to the Service so it knows they are allowed to see data from multiple properties
    const result = await bookingService.getAllBookings(req.user.sub, req.user.role, { page: parseInt(page) || 1, limit: parseInt(limit) || 50, status, search, startDate, endDate, propertyId });
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

// ==========================================
// 4. GET BOOKING BY ID
// ==========================================
export const getBookingById = async (req, res, next) => {
  try {
    // Fetch a single booking's full details using the ID from the URL (e.g., /bookings/12345)
    const booking = await bookingService.getBookingById(req.params.id);
    return sendSuccess(res, { data: { booking } });
  } catch (err) { return next(err); }
};

// ==========================================
// 5. UPDATE BOOKING
// ==========================================
export const updateBooking = async (req, res, next) => {
  try {
    // Pass the Booking ID and the new data (e.g., new check-in date) to the Service
    const booking = await bookingService.updateBooking(req.params.id, req.body);
    // Log the exact update action in the Audit Logs
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Booking', entityId: booking._id, description: `Updated booking for ${booking.guest.name}`, ip: req.ip });
    return sendSuccess(res, { message: 'Booking updated', data: { booking } });
  } catch (err) { return next(err); }
};

// ==========================================
// 6. CANCEL BOOKING
// ==========================================
export const cancelBooking = async (req, res, next) => {
  try {
    // Cancel the booking and require a reason (e.g., "Guest requested cancellation")
    const booking = await bookingService.cancelBooking(req.params.id, req.body.reason);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Booking', entityId: booking._id, description: `Cancelled booking for ${booking.guest.name}`, ip: req.ip });
    return sendSuccess(res, { message: 'Booking cancelled', data: { booking } });
  } catch (err) { return next(err); }
};

// ==========================================
// 7. DELETE BOOKING (Hard delete, usually Admin only)
// ==========================================
export const deleteBooking = async (req, res, next) => {
  try {
    // Permanently erases the booking from MongoDB
    await bookingService.deleteBooking(req.params.id);
    await logAudit({ user: req.user.sub, action: 'delete', entity: 'Booking', entityId: req.params.id, description: 'Deleted booking', ip: req.ip });
    return sendSuccess(res, { message: 'Booking deleted' });
  } catch (err) { return next(err); }
};

// ==========================================
// 8. CHECK IN
// ==========================================
export const checkIn = async (req, res, next) => {
  try {
    // Changes the booking status to 'checked-in' and automatically marks the Room as 'occupied'
    const booking = await bookingService.checkIn(req.params.id);
    await logAudit({ user: req.user.sub, action: 'booking', entity: 'Booking', entityId: booking._id, description: `Checked in: ${booking.guest.name}`, ip: req.ip });
    return sendSuccess(res, { message: 'Guest checked in', data: { booking } });
  } catch (err) { return next(err); }
};

// ==========================================
// 9. CHECK OUT
// ==========================================
export const checkOut = async (req, res, next) => {
  try {
    // Changes the booking status to 'checked-out', marks the Room as 'maintenance', and auto-creates a Housekeeping Task
    const booking = await bookingService.checkOut(req.params.id);
    await logAudit({ user: req.user.sub, action: 'booking', entity: 'Booking', entityId: booking._id, description: `Checked out: ${booking.guest.name}`, ip: req.ip });
    return sendSuccess(res, { message: 'Guest checked out', data: { booking } });
  } catch (err) { return next(err); }
};

// ==========================================
// 10. GET CALENDAR BOOKINGS
// ==========================================
export const getCalendarBookings = async (req, res, next) => {
  try {
    // Fetches a massive, un-paginated list of bookings specifically formatted for the React Big Calendar UI
    const { startDate, endDate } = req.query;
    const bookings = await bookingService.getCalendarBookings(req.params.propertyId, startDate, endDate);
    return sendSuccess(res, { data: { bookings } });
  } catch (err) { return next(err); }
};

// ==========================================
// 11. GET BOOKING STATS
// ==========================================
export const getBookingStats = async (req, res, next) => {
  try {
    // Fetches aggregated math (Total Revenue, Active Guests, Occupancy Rate) for the dashboard charts
    const stats = await bookingService.getBookingStats(req.params.propertyId);
    return sendSuccess(res, { data: stats });
  } catch (err) { return next(err); }
};

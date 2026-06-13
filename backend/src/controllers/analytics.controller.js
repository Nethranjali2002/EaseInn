import * as analyticsService from '../services/analytics.service.js'; // Imports the Brain that calculates complex dashboard stats
import Booking from '../models/booking.model.js'; // DB Model
import Payment from '../models/payment.model.js'; // DB Model
import Room from '../models/room.model.js'; // DB Model
import Task from '../models/task.model.js'; // DB Model
import { sendSuccess } from '../utils/response.util.js'; // Helper for formatting standard JSON responses


// ==========================================
// 1. GET REVENUE REPORT
// ==========================================
export const getRevenueReport = async (req, res, next) => {
  try {
    // Extract date filters (e.g., this month only)
    const { startDate, endDate } = req.query;
    
    // Ask the Service to calculate all the money made in that specific timeframe
    const data = await analyticsService.getRevenueReport(req.params.propertyId, { startDate, endDate });
    return sendSuccess(res, { data });
  } catch (err) { return next(err); }
};


// ==========================================
// 2. GET OCCUPANCY REPORT
// ==========================================
export const getOccupancyReport = async (req, res, next) => {
  try {
    // Calculates what percentage of the hotel is full during a specific timeframe
    const { startDate, endDate } = req.query;
    const data = await analyticsService.getOccupancyReport(req.params.propertyId, { startDate, endDate });
    return sendSuccess(res, { data });
  } catch (err) { return next(err); }
};


// ==========================================
// 3. GET BOOKING TRENDS
// ==========================================
export const getBookingTrends = async (req, res, next) => {
  try {
    // Calculates a month-by-month chart of booking volume (e.g., to draw a line graph)
    const { months } = req.query;
    const data = await analyticsService.getBookingTrends(req.params.propertyId, { months: parseInt(months) || 6 });
    return sendSuccess(res, { data });
  } catch (err) { return next(err); }
};


// ==========================================
// 4. GET TASK PERFORMANCE
// ==========================================
export const getTaskPerformance = async (req, res, next) => {
  try {
    // Calculates how efficiently the staff is completing tasks (e.g., average completion time)
    const data = await analyticsService.getTaskPerformance(req.params.propertyId);
    return sendSuccess(res, { data });
  } catch (err) { return next(err); }
};


// ==========================================
// 5. GET ROOM TYPE PERFORMANCE
// ==========================================
export const getRoomTypePerformance = async (req, res, next) => {
  try {
    // Calculates which types of rooms (Deluxe vs Standard) are making the most money
    const data = await analyticsService.getRoomTypePerformance(req.params.propertyId);
    return sendSuccess(res, { data });
  } catch (err) { return next(err); }
};


// ==========================================
// Helper: TO CSV
// A tiny internal function that converts a Javascript Array into a string of CSV data
// ==========================================
const toCsv = (headers, rows) => {
  const csvHeader = headers.join(',');
  // Maps through the rows, wrapping cells in quotes to prevent commas inside text from breaking the CSV
  const csvRows = rows.map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(',')).join('\n');
  return `${csvHeader}\n${csvRows}`;
};


// ==========================================
// 6. EXPORT BOOKINGS CSV
// ==========================================
export const exportBookingsCsv = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const query = { property: req.params.propertyId };
    if (startDate) query.checkIn = { $gte: new Date(startDate) };
    if (endDate) query.checkOut = { $lte: new Date(endDate) };

    // Fetch raw booking data from the DB
    const bookings = await Booking.find(query).populate('room', 'roomNumber roomType').sort({ createdAt: -1 });

    // Define the columns for the Excel/CSV file
    const headers = ['Guest Name', 'Guest Email', 'Room', 'Check-In', 'Check-Out', 'Guests', 'Total Amount', 'Amount Paid', 'Payment Status', 'Booking Status'];
    
    // Map the database data into those columns
    const rows = bookings.map(b => [
      b.guest?.name, b.guest?.email, b.room?.roomNumber,
      new Date(b.checkIn).toLocaleDateString(), new Date(b.checkOut).toLocaleDateString(),
      b.numberOfGuests, b.pricing?.totalAmount, b.amountPaid, b.paymentStatus, b.bookingStatus,
    ]);

    // Force the browser to download this as a file named "bookings-[timestamp].csv"
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename=bookings-${Date.now()}.csv`);
    return res.send(toCsv(headers, rows));
  } catch (err) { return next(err); }
};


// ==========================================
// 7. EXPORT PAYMENTS CSV
// ==========================================
export const exportPaymentsCsv = async (req, res, next) => {
  try {
    const payments = await Payment.find({ property: req.params.propertyId })
      .populate('booking', 'guest.name')
      .sort({ createdAt: -1 });

    const headers = ['Invoice #', 'Guest', 'Amount', 'Currency', 'Method', 'Type', 'Status', 'Date'];
    const rows = payments.map(p => [
      p.invoiceNumber, p.booking?.guest?.name || 'N/A', p.amount, p.currency,
      p.method, p.type, p.status, p.paidAt ? new Date(p.paidAt).toLocaleDateString() : 'N/A',
    ]);

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename=payments-${Date.now()}.csv`);
    return res.send(toCsv(headers, rows));
  } catch (err) { return next(err); }
};


// ==========================================
// 8. EXPORT ROOMS CSV
// ==========================================
export const exportRoomsCsv = async (req, res, next) => {
  try {
    const rooms = await Room.find({ property: req.params.propertyId }).sort({ roomNumber: 1 });

    const headers = ['Room #', 'Type', 'Name', 'Floor', 'Capacity', 'Base Price', 'Status', 'Amenities'];
    const rows = rooms.map(r => [
      r.roomNumber, r.roomType, r.name, r.floor, r.capacity,
      r.basePrice, r.status, (r.amenities || []).join('; '),
    ]);

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename=rooms-${Date.now()}.csv`);
    return res.send(toCsv(headers, rows));
  } catch (err) { return next(err); }
};


// ==========================================
// 9. EXPORT TASKS CSV
// ==========================================
export const exportTasksCsv = async (req, res, next) => {
  try {
    const tasks = await Task.find({ property: req.params.propertyId })
      .populate('assignedTo', 'name')
      .populate('room', 'roomNumber')
      .sort({ createdAt: -1 });

    const headers = ['Title', 'Type', 'Priority', 'Status', 'Assigned To', 'Room', 'Due Date', 'Completed At'];
    const rows = tasks.map(t => [
      t.title, t.type, t.priority, t.status,
      t.assignedTo?.name || 'Unassigned', t.room?.roomNumber || 'N/A',
      t.dueDate ? new Date(t.dueDate).toLocaleDateString() : 'N/A',
      t.completedAt ? new Date(t.completedAt).toLocaleDateString() : 'N/A',
    ]);

    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename=tasks-${Date.now()}.csv`);
    return res.send(toCsv(headers, rows));
  } catch (err) { return next(err); }
};

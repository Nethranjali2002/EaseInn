import * as analyticsService from '../services/analytics.service.js';
import Booking from '../models/booking.model.js';
import Payment from '../models/payment.model.js';
import Room from '../models/room.model.js';
import Task from '../models/task.model.js';
import { sendSuccess } from '../utils/response.util.js';

export const getRevenueReport = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const data = await analyticsService.getRevenueReport(req.params.propertyId, { startDate, endDate });
    return sendSuccess(res, { data });
  } catch (err) { return next(err); }
};

export const getOccupancyReport = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const data = await analyticsService.getOccupancyReport(req.params.propertyId, { startDate, endDate });
    return sendSuccess(res, { data });
  } catch (err) { return next(err); }
};

export const getBookingTrends = async (req, res, next) => {
  try {
    const { months } = req.query;
    const data = await analyticsService.getBookingTrends(req.params.propertyId, { months: parseInt(months) || 6 });
    return sendSuccess(res, { data });
  } catch (err) { return next(err); }
};

export const getTaskPerformance = async (req, res, next) => {
  try {
    const data = await analyticsService.getTaskPerformance(req.params.propertyId);
    return sendSuccess(res, { data });
  } catch (err) { return next(err); }
};

export const getRoomTypePerformance = async (req, res, next) => {
  try {
    const data = await analyticsService.getRoomTypePerformance(req.params.propertyId);
    return sendSuccess(res, { data });
  } catch (err) { return next(err); }
};

const toCsv = (headers, rows) => {
  const csvHeader = headers.join(',');
  const csvRows = rows.map(row => row.map(cell => `"${String(cell).replace(/"/g, '""')}"`).join(',')).join('\n');
  return `${csvHeader}\n${csvRows}`;
};

export const exportBookingsCsv = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const query = { property: req.params.propertyId };
    if (startDate) query.checkIn = { $gte: new Date(startDate) };
    if (endDate) query.checkOut = { $lte: new Date(endDate) };
    const bookings = await Booking.find(query).populate('room', 'roomNumber roomType').sort({ createdAt: -1 });
    const headers = ['Guest Name', 'Guest Email', 'Room', 'Check-In', 'Check-Out', 'Guests', 'Total Amount', 'Amount Paid', 'Payment Status', 'Booking Status'];
    const rows = bookings.map(b => [
      b.guest?.name, b.guest?.email, b.room?.roomNumber,
      new Date(b.checkIn).toLocaleDateString(), new Date(b.checkOut).toLocaleDateString(),
      b.numberOfGuests, b.pricing?.totalAmount, b.amountPaid, b.paymentStatus, b.bookingStatus,
    ]);
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', `attachment; filename=bookings-${Date.now()}.csv`);
    return res.send(toCsv(headers, rows));
  } catch (err) { return next(err); }
};

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

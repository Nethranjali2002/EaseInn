import Booking from '../models/booking.model.js';
import Payment from '../models/payment.model.js';
import { sendSuccess } from '../utils/response.util.js';
import { generateBookingReportPdf, generatePaymentReportPdf } from '../utils/pdf.util.js';

export const exportBookingsPdf = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const query = { property: req.params.propertyId };
    if (startDate) query.checkIn = { $gte: new Date(startDate) };
    if (endDate) query.checkOut = { $lte: new Date(endDate) };

    const bookings = await Booking.find(query)
      .populate('room', 'roomNumber roomType')
      .populate('property', 'name')
      .sort({ createdAt: -1 });

    const property = bookings[0]?.room ? { name: bookings[0]?.property?.name } : null;
    generateBookingReportPdf(res, { bookings, property, startDate, endDate });
  } catch (err) { return next(err); }
};

export const exportPaymentsPdf = async (req, res, next) => {
  try {
    const payments = await Payment.find({ property: req.params.propertyId })
      .populate('booking')
      .populate('property', 'name')
      .sort({ createdAt: -1 });

    const property = payments[0]?.property ? { name: payments[0].property.name } : null;
    generatePaymentReportPdf(res, { payments, property });
  } catch (err) { return next(err); }
};

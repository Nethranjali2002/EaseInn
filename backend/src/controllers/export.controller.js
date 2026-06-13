import Booking from '../models/booking.model.js'; // Imports the Mongoose Model for Bookings
import Payment from '../models/payment.model.js'; // Imports the Mongoose Model for Payments
import { sendSuccess } from '../utils/response.util.js'; // Helper for JSON responses (though PDFs don't always use this)
import { generateBookingReportPdf, generatePaymentReportPdf } from '../utils/pdf.util.js'; // Imports our custom PDF creation engine


// ==========================================
// 1. EXPORT BOOKINGS PDF
// ==========================================
export const exportBookingsPdf = async (req, res, next) => {
  try {
    // Check if the user wants to filter the PDF report by specific dates
    const { startDate, endDate } = req.query;
    
    // Build a MongoDB query specifically for this property
    const query = { property: req.params.propertyId };
    if (startDate) query.checkIn = { $gte: new Date(startDate) };
    if (endDate) query.checkOut = { $lte: new Date(endDate) };

    // Fetch the raw data from MongoDB and pull in the readable Room and Property names
    const bookings = await Booking.find(query)
      .populate('room', 'roomNumber roomType')
      .populate('property', 'name')
      .sort({ createdAt: -1 });

    // Try to get the property name from the first booking to use in the PDF Header
    const property = bookings[0]?.room ? { name: bookings[0]?.property?.name } : null;
    
    // Pass the raw data to our PDF engine, which will format it into a neat table and stream it directly to the user's browser download
    generateBookingReportPdf(res, { bookings, property, startDate, endDate });
  } catch (err) { return next(err); }
};


// ==========================================
// 2. EXPORT PAYMENTS PDF
// ==========================================
export const exportPaymentsPdf = async (req, res, next) => {
  try {
    // Fetch all financial transactions for this property
    const payments = await Payment.find({ property: req.params.propertyId })
      .populate('booking')
      .populate('property', 'name')
      .sort({ createdAt: -1 });

    // Try to get the property name for the PDF Header
    const property = payments[0]?.property ? { name: payments[0].property.name } : null;
    
    // Stream the financial ledger as a PDF download to the user's browser
    generatePaymentReportPdf(res, { payments, property });
  } catch (err) { return next(err); }
};

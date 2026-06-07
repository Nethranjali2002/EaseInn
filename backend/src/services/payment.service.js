import Payment from '../models/payment.model.js';
import Booking from '../models/booking.model.js';
import { AppError } from '../middlewares/error.middleware.js';
import { generatePaymentCode } from '../utils/codeGenerator.js';

const generateInvoiceNumber = (propertyId) => {
  const timestamp = Date.now().toString(36).toUpperCase();
  const random = Math.random().toString(36).substring(2, 6).toUpperCase();
  return `INV-${timestamp}-${random}`;
};

export const createPayment = async (data, recordedBy) => {
  const booking = await Booking.findById(data.booking);
  if (!booking) throw new AppError('Booking not found', 404);

  if (data.status !== 'completed') {
    const existingPending = await Payment.findOne({
      booking: booking._id,
      status: 'pending',
      amount: data.amount,
      method: data.method,
    });
    if (existingPending) {
      throw new AppError('A pending payment with the same amount and method already exists for this booking', 409);
    }
  }

  if (data.status === 'completed') {
    const existingCompleted = await Payment.findOne({
      booking: booking._id,
      status: 'completed',
      amount: data.amount,
      method: data.method,
      type: data.type || 'partial',
    });
    if (existingCompleted) {
      throw new AppError('A completed payment with the same amount and method already exists for this booking', 409);
    }

    const outstanding = booking.pricing.totalAmount - booking.amountPaid;
    if (data.amount > outstanding + 1) {
      throw new AppError(`Payment amount (LKR ${data.amount}) exceeds outstanding balance (LKR ${outstanding})`, 400);
    }
  }

  const payment = await Payment.create({
    ...data,
    code: await generatePaymentCode(),
    property: booking.property,
    recordedBy,
    invoiceNumber: generateInvoiceNumber(booking.property),
    paidAt: data.status === 'completed' ? new Date() : undefined,
  });

  if (data.status === 'completed') {
    const totalPaid = await Payment.aggregate([
      { $match: { booking: booking._id, status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]);

    const amountPaid = totalPaid.length > 0 ? totalPaid[0].total : 0;
    const paymentStatus = amountPaid >= booking.pricing.totalAmount ? 'paid' : amountPaid > 0 ? 'partial' : 'pending';

    const bookingUpdates = { amountPaid, paymentStatus };
    if (paymentStatus === 'paid') {
      if (booking.bookingStatus === 'pending-payment') {
        bookingUpdates.bookingStatus = 'confirmed';
      } else if (booking.bookingStatus === 'checked-out') {
        bookingUpdates.bookingStatus = 'completed';
      }
    }

    await Booking.findByIdAndUpdate(booking._id, bookingUpdates);
  }

  return payment;
};

export const getPayments = async (propertyId, { page = 1, limit = 20, status, bookingId }) => {
  const query = { property: propertyId };
  if (status) query.status = status;
  if (bookingId) query.booking = bookingId;

  const total = await Payment.countDocuments(query);
  const payments = await Payment.find(query)
    .populate('booking', 'guest.name checkIn checkOut')
    .populate('recordedBy', 'name email')
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
  return { payments, total, page, limit };
};

export const getPaymentById = async (paymentId) => {
  const payment = await Payment.findById(paymentId)
    .populate('booking', 'guest.name guest.email checkIn checkOut pricing')
    .populate('recordedBy', 'name email');
  if (!payment) throw new AppError('Payment not found', 404);
  return payment;
};

export const updatePaymentStatus = async (paymentId, status, gatewayData) => {
  const payment = await Payment.findByIdAndUpdate(
    paymentId,
    {
      status,
      ...(gatewayData && { gateway: gatewayData }),
      ...(status === 'completed' && { paidAt: new Date() }),
    },
    { new: true }
  );
  if (!payment) throw new AppError('Payment not found', 404);

  if (status === 'completed') {
    const totalPaid = await Payment.aggregate([
      { $match: { booking: payment.booking, status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: null, total: { $sum: '$amount' } } },
    ]);

    const amountPaid = totalPaid.length > 0 ? totalPaid[0].total : 0;
    const booking = await Booking.findById(payment.booking);
    const paymentStatus = amountPaid >= booking.pricing.totalAmount ? 'paid' : amountPaid > 0 ? 'partial' : 'pending';

    const bookingUpdates = { amountPaid, paymentStatus };
    if (paymentStatus === 'paid') {
      if (booking.bookingStatus === 'pending-payment') {
        bookingUpdates.bookingStatus = 'confirmed';
      } else if (booking.bookingStatus === 'checked-out') {
        bookingUpdates.bookingStatus = 'completed';
      }
    }

    await Booking.findByIdAndUpdate(payment.booking, bookingUpdates);
  }

  return payment;
};

export const getPaymentStats = async (propertyId) => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const totalRevenue = await Payment.aggregate([
    { $match: { property: propertyId, status: 'completed', type: { $ne: 'refund' } } },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);

  const todayRevenue = await Payment.aggregate([
    { $match: { property: propertyId, status: 'completed', type: { $ne: 'refund' }, paidAt: { $gte: today } } },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);

  return {
    totalRevenue: totalRevenue.length > 0 ? totalRevenue[0].total : 0,
    todayRevenue: todayRevenue.length > 0 ? todayRevenue[0].total : 0,
  };
};

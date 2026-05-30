import Booking from '../models/booking.model.js';
import Room from '../models/room.model.js';
import Property from '../models/property.model.js';
import Task from '../models/task.model.js';
import { AppError } from '../middlewares/error.middleware.js';
import crypto from 'crypto';
import { env } from '../config/env.config.js';
import { sendReviewInvitation } from '../utils/email.util.js';
import { sendBookingSMS } from '../utils/sms.util.js';
import logger from '../utils/logger.util.js';


const calculateNights = (checkIn, checkOut) => {
  const diff = new Date(checkOut) - new Date(checkIn);
  return Math.ceil(diff / (1000 * 60 * 60 * 24));
};

export const createBooking = async (data, userId) => {
  const room = await Room.findById(data.room);
  if (!room) throw new AppError('Room not found', 404);

  const propertyDoc = await Property.findById(data.property);
  if (!propertyDoc) throw new AppError('Property not found', 404);

  const overlappingBooking = await Booking.findOne({
    room: data.room,
    bookingStatus: { $in: ['confirmed', 'checked-in'] },
    $or: [
      { checkIn: { $lt: new Date(data.checkOut) }, checkOut: { $gt: new Date(data.checkIn) } },
    ],
  });
  if (overlappingBooking) throw new AppError('Room is already booked for these dates', 409);

  const nights = calculateNights(data.checkIn, data.checkOut);
  const roomTotal = room.basePrice * nights;

  let mealPlanTotal = 0;
  if (data.mealPlan && room.mealPlans?.length) {
    const selectedPlan = room.mealPlans.find(mp => mp.name === data.mealPlan);
    if (selectedPlan) {
      mealPlanTotal = selectedPlan.price * nights;
    }
  }

  const addonsTotal = (data.addons || []).reduce((sum, a) => sum + (a.price || 0), 0);
  const subtotal = roomTotal + mealPlanTotal + addonsTotal - (data.discount || 0);

  const taxRate = propertyDoc?.taxRate || 0;
  const tax = subtotal * (taxRate / 100);
  const totalAmount = subtotal + tax;

  const booking = await Booking.create({
    ...data,
    createdBy: userId,
    pricing: {
      basePrice: room.basePrice,
      nights,
      roomTotal,
      mealPlanTotal,
      addons: data.addons || [],
      discount: data.discount || 0,
      tax,
      totalAmount,
    },
  });

  await Room.findByIdAndUpdate(data.room, { status: 'booked' });
  return booking;
};

export const createGuestBooking = async (data) => {
  const room = await Room.findById(data.room);
  if (!room) throw new AppError('Room not found', 404);

  const property = await Property.findById(data.property);
  if (!property) throw new AppError('Property not found', 404);

  const overlappingBooking = await Booking.findOne({
    room: data.room,
    bookingStatus: { $in: ['confirmed', 'checked-in'] },
    $or: [
      { checkIn: { $lt: new Date(data.checkOut) }, checkOut: { $gt: new Date(data.checkIn) } },
    ],
  });
  if (overlappingBooking) throw new AppError('Room is already booked for these dates', 409);

  const nights = calculateNights(data.checkIn, data.checkOut);
  const roomTotal = room.basePrice * nights;

  let mealPlanTotal = 0;
  if (data.mealPlan && room.mealPlans?.length) {
    const selectedPlan = room.mealPlans.find(mp => mp.name === data.mealPlan);
    if (selectedPlan) {
      mealPlanTotal = selectedPlan.price * nights;
    }
  }

  const addonsTotal = (data.addons || []).reduce((sum, a) => sum + (a.price || 0), 0);
  const subtotal = roomTotal + mealPlanTotal + addonsTotal - (data.discount || 0);

  const taxRate = property?.taxRate || 0;
  const tax = subtotal * (taxRate / 100);
  const totalAmount = subtotal + tax;

  // Find an admin/manager of this property to set as createdBy
  const User = (await import('../models/user.model.js')).default;
  const propertyOwner = await User.findOne({ _id: property.owner });

  const booking = await Booking.create({
    ...data,
    createdBy: propertyOwner?._id || property.owner,
    source: 'website',
    pricing: {
      basePrice: room.basePrice,
      nights,
      roomTotal,
      mealPlanTotal,
      addons: data.addons || [],
      discount: data.discount || 0,
      tax,
      totalAmount,
    },
  });

  await Room.findByIdAndUpdate(data.room, { status: 'booked' });
  return booking;
};

export const getBookings = async (propertyId, { page = 1, limit = 20, status, search = '', startDate, endDate }) => {
  const query = { property: propertyId };
  if (status) query.bookingStatus = status;
  if (search) {
    query.$or = [
      { 'guest.name': { $regex: search, $options: 'i' } },
      { 'guest.email': { $regex: search, $options: 'i' } },
      { 'guest.phone': { $regex: search, $options: 'i' } },
    ];
  }
  if (startDate && endDate) {
    query.checkIn = { $gte: new Date(startDate) };
    query.checkOut = { $lte: new Date(endDate) };
  }

  const total = await Booking.countDocuments(query);
  const bookings = await Booking.find(query)
    .populate('room', 'roomNumber roomType name')
    .populate('createdBy', 'name email')
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
  return { bookings, total, page, limit };
};

export const getBookingById = async (bookingId) => {
  const booking = await Booking.findById(bookingId)
    .populate('room', 'roomNumber roomType name capacity')
    .populate('property', 'name address')
    .populate('createdBy', 'name email');
  if (!booking) throw new AppError('Booking not found', 404);
  return booking;
};

export const updateBooking = async (bookingId, updates) => {
  const booking = await Booking.findByIdAndUpdate(bookingId, { $set: updates }, { new: true, runValidators: true });
  if (!booking) throw new AppError('Booking not found', 404);
  return booking;
};

export const cancelBooking = async (bookingId, reason) => {
  const booking = await Booking.findByIdAndUpdate(
    bookingId,
    { bookingStatus: 'cancelled', cancellationReason: reason, cancelledAt: new Date() },
    { new: true }
  );
  if (!booking) throw new AppError('Booking not found', 404);
  await Room.findByIdAndUpdate(booking.room, { status: 'available' });
  return booking;
};

export const checkIn = async (bookingId) => {
  const booking = await Booking.findById(bookingId)
    .populate('room', 'roomNumber');
  if (!booking) throw new AppError('Booking not found', 404);

  booking.bookingStatus = 'checked-in';
  await booking.save();

  await Room.findByIdAndUpdate(booking.room._id, { status: 'occupied' });

  if (booking.guest?.phone) {
    sendBookingSMS(booking.guest.phone, booking.guest.name, {
      checkIn: booking.checkIn,
      room: { roomNumber: booking.room?.roomNumber || 'TBD' },
    }).catch((err) => logger.error(`Check-in SMS failed: ${err.message}`));
  }

  return booking;
};

export const checkOut = async (bookingId) => {
  const booking = await Booking.findById(bookingId)
    .populate('property', 'name')
    .populate('room', 'roomNumber');
  if (!booking) throw new AppError('Booking not found', 404);

  const reviewToken = crypto.randomBytes(32).toString('hex');
  const reviewTokenExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

  const updated = await Booking.findByIdAndUpdate(
    bookingId,
    { bookingStatus: 'checked-out', reviewToken, reviewTokenExpiresAt },
    { new: true }
  );

  await Room.findByIdAndUpdate(booking.room._id, { status: 'cleaning' });

  // Auto-create housekeeping task on check-out
  try {
    await Task.create({
      property: booking.property._id,
      title: `Housekeeping - Room ${booking.room.roomNumber}`,
      description: `Clean and prepare Room ${booking.room.roomNumber} after guest checkout.`,
      type: 'housekeeping',
      priority: 'high',
      status: 'open',
      assignedBy: booking.createdBy,
      room: booking.room._id,
      booking: booking._id,
      dueDate: new Date(),
      subtasks: [
        { title: 'Strip and remake beds' },
        { title: 'Clean and sanitize bathroom' },
        { title: 'Vacuum and mop floors' },
        { title: 'Restock amenities' },
        { title: 'Inspect for damages' },
      ],
      checklist: [
        { item: 'Towels replaced' },
        { item: 'Sheets replaced' },
        { item: 'Toiletries restocked' },
        { item: 'Room key reset' },
      ],
    });
  } catch (err) {
    logger.error(`Auto housekeeping task creation failed: ${err.message}`);
  }

  // Send review invitation email if guest has an email
  if (booking.guest?.email) {
    const appUrl = env.appUrl;
    const reviewLink = `${appUrl}/#/web/review?token=${reviewToken}`;
    sendReviewInvitation(booking.guest.email, booking.guest.name, {
      propertyName: booking.property?.name || 'EaseInn',
      roomNumber: booking.room?.roomNumber || 'N/A',
      checkIn: booking.checkIn,
      checkOut: booking.checkOut,
      reviewLink,
    }).catch((err) => logger.error(`Review invitation email failed: ${err.message}`));
  }

  return updated;
};

export const getCalendarBookings = async (propertyId, startDate, endDate) => {
  const bookings = await Booking.find({
    property: propertyId,
    checkIn: { $lte: new Date(endDate) },
    checkOut: { $gte: new Date(startDate) },
    bookingStatus: { $in: ['confirmed', 'checked-in'] },
  })
    .populate('room', 'roomNumber roomType name')
    .sort({ checkIn: 1 });
  return bookings;
};

export const getBookingStats = async (propertyId) => {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  const totalBookings = await Booking.countDocuments({ property: propertyId });
  const activeBookings = await Booking.countDocuments({
    property: propertyId,
    bookingStatus: { $in: ['confirmed', 'checked-in'] },
  });
  const todayCheckIns = await Booking.countDocuments({
    property: propertyId,
    checkIn: { $gte: today, $lt: tomorrow },
    bookingStatus: { $in: ['confirmed', 'checked-in'] },
  });
  const todayCheckOuts = await Booking.countDocuments({
    property: propertyId,
    checkOut: { $gte: today, $lt: tomorrow },
    bookingStatus: { $in: ['checked-in'] },
  });
  const pendingPayments = await Booking.countDocuments({
    property: propertyId,
    paymentStatus: { $in: ['pending', 'partial'] },
    bookingStatus: { $in: ['confirmed', 'checked-in'] },
  });

  return { totalBookings, activeBookings, todayCheckIns, todayCheckOuts, pendingPayments };
};

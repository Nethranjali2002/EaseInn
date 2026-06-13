import Booking from '../models/booking.model.js'; // The database model representing a reservation
import Room from '../models/room.model.js'; // The database model representing the physical hotel room
import Property from '../models/property.model.js'; // The database model representing the hotel itself
import Task from '../models/task.model.js'; // The database model representing chores/maintenance
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing specific HTTP errors
import crypto from 'crypto'; // Native Node library used here to generate secure review links
import { env } from '../config/env.config.js'; // Environment variables (e.g. frontend URL)
import { sendReviewInvitation } from '../utils/email.util.js'; // Email sending service
import { sendBookingSMS } from '../utils/sms.util.js'; // Twilio SMS sending service
import logger from '../utils/logger.util.js'; // Server logging tool
import { generateBookingCode, generateTaskCode } from '../utils/codeGenerator.js'; // Utility to create readable IDs like "BKG-X9Y2"

// This dictionary enforces a strict linear workflow.
// Example: A 'draft' booking can only become 'pending-payment' or 'cancelled'. It cannot jump to 'completed'.
const VALID_TRANSITIONS = {
  'pending-payment': ['confirmed', 'cancelled'],
  'confirmed': ['checked-in', 'cancelled'],
  'checked-in': ['checked-out'],
  'checked-out': ['completed'],
  'completed': [],
  'cancelled': [],
  'draft': ['pending-payment', 'cancelled'],
};

// ==========================================
// 1. CAN TRANSITION (Helper)
// Verifies if the requested status change is logically permitted by the dictionary above
// ==========================================
const canTransition = (from, to) => VALID_TRANSITIONS[from]?.includes(to) ?? false;

// ==========================================
// 2. CALCULATE NIGHTS (Helper)
// Determines how many days a guest is staying (used to multiply the price)
// ==========================================
const calculateNights = (checkIn, checkOut) => {
  const diff = new Date(checkOut) - new Date(checkIn);
  return Math.ceil(diff / (1000 * 60 * 60 * 24)); // Convert milliseconds to full days
};

// ==========================================
// 3. CREATE BOOKING (Manager/Staff View)
// Called when a front desk worker manually creates a reservation
// ==========================================
export const createBooking = async (data, userId) => {
  const room = await Room.findById(data.room);
  if (!room) throw new AppError('Room not found', 404);

  // Security Check: Ensure the room selected actually belongs to the current hotel dashboard
  if (room.property.toString() !== data.property) {
    throw new AppError('Room does not belong to this property', 400);
  }

  const propertyDoc = await Property.findById(data.property);
  if (!propertyDoc) throw new AppError('Property not found', 404);

  // The Booking Algorithm: Ensure nobody else is sleeping in this room on these exact dates
  const overlappingBooking = await Booking.findOne({
    room: data.room,
    bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] },
    // Logic: (Existing_CheckIn < New_CheckOut) AND (Existing_CheckOut > New_CheckIn)
    $or: [
      { checkIn: { $lt: new Date(data.checkOut) }, checkOut: { $gt: new Date(data.checkIn) } },
    ],
  });
  if (overlappingBooking) throw new AppError('Room is already booked for these dates', 409);

  // Dynamic Pricing Engine
  const nights = calculateNights(data.checkIn, data.checkOut);
  const roomTotal = room.basePrice * nights; // Base calculation

  // Add meal plan costs if selected
  let mealPlanTotal = 0;
  if (data.mealPlan && room.mealPlans?.length) {
    const selectedPlan = room.mealPlans.find(mp => mp.name === data.mealPlan);
    if (selectedPlan) {
      mealPlanTotal = selectedPlan.price * nights;
    }
  }

  // Calculate extras (e.g. airport pickup, extra bed)
  const addonsTotal = (data.addons || []).reduce((sum, a) => sum + (a.price || 0), 0);
  
  const subtotal = roomTotal + mealPlanTotal + addonsTotal - (data.discount || 0);

  // Calculate final tax based on the hotel's configured tax rate
  const taxRate = propertyDoc?.taxRate || 0;
  const tax = subtotal * (taxRate / 100);
  const totalAmount = subtotal + tax;

  // Save everything to the database
  const booking = await Booking.create({
    ...data,
    code: await generateBookingCode(), // e.g. "BKG-ABCD"
    createdBy: userId, // Record which staff member made this booking
    pricing: {
      basePrice: room.basePrice,
      nights,
      roomTotal,
      mealPlanTotal,
      addons: data.addons || [],
      discount: data.discount || 0,
      tax,
      totalAmount, // The grand total the guest actually pays
    },
  });

  // Temporarily block out the room so it stops showing up in searches
  await Room.findByIdAndUpdate(data.room, { status: 'booked' });
  return booking;
};

// ==========================================
// 4. CREATE GUEST BOOKING (Website View)
// Called when a guest uses the public booking site to book themselves
// ==========================================
export const createGuestBooking = async (data) => {
  const room = await Room.findById(data.room);
  if (!room) throw new AppError('Room not found', 404);

  if (room.property.toString() !== data.property) {
    throw new AppError('Room does not belong to this property', 400);
  }

  const property = await Property.findById(data.property);
  if (!property) throw new AppError('Property not found', 404);

  // Overlap protection algorithms (Identical to staff creation)
  const overlappingBooking = await Booking.findOne({
    room: data.room,
    bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] },
    $or: [
      { checkIn: { $lt: new Date(data.checkOut) }, checkOut: { $gt: new Date(data.checkIn) } },
    ],
  });
  if (overlappingBooking) throw new AppError('Room is already booked for these dates', 409);

  // Pricing math engine
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

  // We assign the 'createdBy' flag to the Hotel Owner, since the guest doesn't have a staff ID
  const User = (await import('../models/user.model.js')).default;
  const propertyOwner = await User.findOne({ _id: property.owner });

  const booking = await Booking.create({
    ...data,
    code: await generateBookingCode(),
    createdBy: propertyOwner?._id || property.owner,
    source: 'website', // Identifies this as an external public booking
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

// ==========================================
// 5. GET BOOKINGS (Filtered)
// The main function used to populate the Manager's booking table
// ==========================================
export const getBookings = async (propertyId, { page = 1, limit = 20, status, search = '', startDate, endDate }) => {
  const property = await Property.findById(propertyId);
  if (!property) throw new AppError('Property not found', 404);

  const query = { property: propertyId };
  if (status) query.bookingStatus = status;
  
  // High-performance text searching allowing receptionists to search by guest name, email, or phone
  if (search) {
    query.$or = [
      { 'guest.name': { $regex: search, $options: 'i' } },
      { 'guest.email': { $regex: search, $options: 'i' } },
      { 'guest.phone': { $regex: search, $options: 'i' } },
    ];
  }
  
  // Filter by a specific date window
  if (startDate && endDate) {
    query.checkIn = { $gte: new Date(startDate) };
    query.checkOut = { $lte: new Date(endDate) };
  }

  const total = await Booking.countDocuments(query);
  const bookings = await Booking.find(query)
    .populate('room', 'roomNumber roomType name')
    .populate('createdBy', 'name email')
    .sort({ createdAt: -1 }) // Show newest bookings at the top
    .skip((page - 1) * limit)
    .limit(limit);
  return { bookings, total, page, limit };
};

// ==========================================
// 6. GET ALL BOOKINGS (Admin View)
// Allows a Super Admin to see bookings across ALL properties simultaneously
// ==========================================
export const getAllBookings = async (userId, userRole, { page = 1, limit = 50, status, search = '', startDate, endDate, propertyId }) => {
  const query = {};
  
  if (propertyId) {
    query.property = propertyId;
  } else if (userRole === 'admin') {
    // If the user is an owner, fetch ALL of their properties, then find all bookings in those properties
    const properties = await Property.find({ owner: userId }).select('_id');
    query.property = { $in: properties.map(p => p._id) };
  } else {
    // Manager/staff logic
  }
  
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
    .populate('property', 'name address') // Also populate the hotel name since this spans multiple hotels
    .populate('createdBy', 'name email')
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
  return { bookings, total, page, limit };
};

// ==========================================
// 7. GET BOOKING BY ID
// ==========================================
export const getBookingById = async (bookingId) => {
  const booking = await Booking.findById(bookingId)
    .populate('room', 'roomNumber roomType name capacity')
    .populate('property', 'name address')
    .populate('createdBy', 'name email');
  if (!booking) throw new AppError('Booking not found', 404);
  return booking;
};

// Strict list of fields that managers are allowed to alter on an existing reservation
const ALLOWED_BOOKING_UPDATES = ['checkIn', 'checkOut', 'specialRequests', 'notes', 'guest', 'numberOfGuests', 'adults', 'children', 'mealPlan', 'addons', 'discount', 'room', 'roomType', 'bookingStatus', 'cancellationReason'];

// ==========================================
// 8. UPDATE BOOKING
// Highly complex function because changing a room or a date requires recalculating the entire invoice and checking for overlaps
// ==========================================
export const updateBooking = async (bookingId, updates) => {
  const booking = await Booking.findById(bookingId);
  if (!booking) throw new AppError('Booking not found', 404);

  // You cannot edit a booking if the guest is currently in the room or has left
  if (['checked-in', 'checked-out', 'completed', 'cancelled'].includes(booking.bookingStatus)) {
    throw new AppError(`Cannot update booking in '${booking.bookingStatus}' status`, 409);
  }

  // Clean the incoming data using our whitelist
  const sanitized = {};
  for (const key of ALLOWED_BOOKING_UPDATES) {
    if (updates[key] !== undefined) sanitized[key] = updates[key];
  }

  if (Object.keys(sanitized).length === 0) {
    throw new AppError('No valid fields to update', 400);
  }

  // IF THEY ARE TRYING TO MOVE THE GUEST TO A DIFFERENT ROOM:
  if (sanitized.room) {
    const newRoom = await Room.findById(sanitized.room);
    if (!newRoom) throw new AppError('Room not found', 404);
    
    // Security check
    const bookingPropertyId = booking.property.toString();
    if (newRoom.property.toString() !== bookingPropertyId) {
      throw new AppError('Room does not belong to this property', 400);
    }
    
    // Check if the NEW room is empty on the requested dates
    const overlappingBooking = await Booking.findOne({
      room: sanitized.room,
      _id: { $ne: bookingId }, // Ignore the current booking itself
      bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] },
      $or: [
        { checkIn: { $lt: new Date(sanitized.checkOut || booking.checkOut) }, checkOut: { $gt: new Date(sanitized.checkIn || booking.checkIn) } },
      ],
    });
    if (overlappingBooking) throw new AppError('Room is already booked for these dates', 409);
    
    // Free up the old room, and lock down the new room
    await Room.findByIdAndUpdate(booking.room, { status: 'available' });
    await Room.findByIdAndUpdate(sanitized.room, { status: 'booked' });
  }

  // Apply the updates
  const updated = await Booking.findByIdAndUpdate(bookingId, { $set: sanitized }, { new: true, runValidators: true });

  // IF ANY PRICING VARIABLE CHANGED (dates, rooms, meals, discounts):
  // We must re-run the entire pricing math engine to generate a new invoice
  if (sanitized.checkIn || sanitized.checkOut || sanitized.room || sanitized.mealPlan || sanitized.discount !== undefined || sanitized.addons) {
    const freshBooking = await Booking.findById(bookingId);
    const roomId = freshBooking.room;
    const room = await Room.findById(roomId);
    const propertyDoc = await Property.findById(freshBooking.property);

    // Re-calculate
    const nights = calculateNights(freshBooking.checkIn, freshBooking.checkOut);
    const basePrice = room.basePrice;
    const roomTotal = basePrice * nights;

    let mealPlanTotal = 0;
    if (freshBooking.mealPlan && room.mealPlans?.length) {
      const selectedPlan = room.mealPlans.find(mp => mp.name === freshBooking.mealPlan);
      if (selectedPlan) mealPlanTotal = selectedPlan.price * nights;
    }

    const addonsTotal = (freshBooking.pricing?.addons || []).reduce((sum, a) => sum + (a.price || 0), 0);
    const discount = freshBooking.pricing?.discount || 0;
    const subtotal = roomTotal + mealPlanTotal + addonsTotal - discount;
    const taxRate = propertyDoc?.taxRate || 0;
    const tax = subtotal * (taxRate / 100);
    const totalAmount = subtotal + tax;

    // Apply the newly calculated invoice
    await Booking.findByIdAndUpdate(bookingId, {
      $set: {
        pricing: {
          basePrice,
          nights,
          roomTotal,
          mealPlanTotal,
          addons: freshBooking.pricing?.addons || [],
          discount,
          tax,
          totalAmount,
        },
      },
    });
  }

  return await Booking.findById(bookingId);
};

// ==========================================
// 9. CANCEL BOOKING
// ==========================================
export const cancelBooking = async (bookingId, reason) => {
  const booking = await Booking.findById(bookingId);
  if (!booking) throw new AppError('Booking not found', 404);

  // Utilize the strict transition dictionary
  if (!canTransition(booking.bookingStatus, 'cancelled')) {
    throw new AppError(`Cannot cancel booking in '${booking.bookingStatus}' status`, 409);
  }

  // Mark as cancelled and record why
  booking.bookingStatus = 'cancelled';
  booking.cancellationReason = reason || 'No reason provided';
  booking.cancelledAt = new Date();
  await booking.save();

  // Free up the physical room for someone else to book
  await Room.findByIdAndUpdate(booking.room, { status: 'available' });
  return booking;
};

// ==========================================
// 10. DELETE BOOKING (Dangerous)
// Completely obliterates the record. Used mainly for testing or extreme errors.
// ==========================================
export const deleteBooking = async (bookingId) => {
  const booking = await Booking.findById(bookingId);
  if (!booking) throw new AppError('Booking not found', 404);

  // Prevent financial fraud: If they checked in, a permanent record must be kept.
  if (['checked-in', 'checked-out', 'completed'].includes(booking.bookingStatus)) {
    throw new AppError(`Cannot delete booking in '${booking.bookingStatus}' status. Cancel it first.`, 409);
  }

  await Room.findByIdAndUpdate(booking.room, { status: 'available' });
  await Booking.findByIdAndDelete(bookingId);
  return booking;
};

// ==========================================
// 11. CHECK IN
// Triggered when the guest arrives at the front desk
// ==========================================
export const checkIn = async (bookingId) => {
  const booking = await Booking.findById(bookingId)
    .populate('room', 'roomNumber');
  if (!booking) throw new AppError('Booking not found', 404);

  // Prevent double check-ins
  if (!canTransition(booking.bookingStatus, 'checked-in')) {
    throw new AppError(`Cannot check in booking in '${booking.bookingStatus}' status`, 409);
  }

  booking.bookingStatus = 'checked-in';
  await booking.save();

  // Inform the entire hotel system that someone is actively in this room
  await Room.findByIdAndUpdate(booking.room._id, { status: 'occupied' });

  // If we have their phone number, text them a welcome message using Twilio
  if (booking.guest?.phone) {
    sendBookingSMS(booking.guest.phone, booking.guest.name, {
      checkIn: booking.checkIn,
      room: { roomNumber: booking.room?.roomNumber || 'TBD' },
    }).catch((err) => logger.error(`Check-in SMS failed: ${err.message}`));
  }

  return booking;
};

// ==========================================
// 12. CHECK OUT
// Triggered when the guest hands back the keys.
// Includes automated workflows for housekeeping and emails.
// ==========================================
export const checkOut = async (bookingId) => {
  const booking = await Booking.findById(bookingId)
    .populate('property', 'name')
    .populate('room', 'roomNumber');
  if (!booking) throw new AppError('Booking not found', 404);

  if (!canTransition(booking.bookingStatus, 'checked-out')) {
    throw new AppError(`Cannot check out booking in '${booking.bookingStatus}' status`, 409);
  }

  // Generate a highly secure, one-time link that the guest can use to leave a review
  const reviewToken = crypto.randomBytes(32).toString('hex');
  const reviewTokenExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // Expires in 30 days

  // If they owe money, they are 'checked-out'. If they paid everything, the reservation is permanently 'completed'
  const newStatus = booking.paymentStatus === 'paid' ? 'completed' : 'checked-out';
  const updated = await Booking.findByIdAndUpdate(
    bookingId,
    { bookingStatus: newStatus, reviewToken, reviewTokenExpiresAt },
    { new: true }
  );

  // Tell the system the room is dirty
  await Room.findByIdAndUpdate(booking.room._id, { status: 'cleaning' });

  // AUTOMATION: Automatically generate a housekeeping ticket to clean the room
  try {
    await Task.create({
      code: await generateTaskCode(),
      property: booking.property._id,
      title: `Housekeeping - Room ${booking.room.roomNumber}`,
      description: `Clean and prepare Room ${booking.room.roomNumber} after guest checkout.`,
      type: 'housekeeping',
      priority: 'high', // Urgent, since someone else might be checking in today
      status: 'open',
      assignedBy: booking.createdBy,
      room: booking.room._id,
      booking: booking._id,
      dueDate: new Date(), // Due today
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

  // AUTOMATION: Send the 'Thank You' email containing the one-time review link
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

// ==========================================
// 13. GET CALENDAR BOOKINGS
// Specialized query just for populating the Drag-and-Drop Calendar UI
// ==========================================
export const getCalendarBookings = async (propertyId, startDate, endDate) => {
  const property = await Property.findById(propertyId);
  if (!property) throw new AppError('Property not found', 404);

  const bookings = await Booking.find({
    property: propertyId,
    checkIn: { $lte: new Date(endDate) },
    checkOut: { $gte: new Date(startDate) },
    bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in', 'checked-out', 'completed'] },
  })
    .populate('room', 'roomNumber roomType name')
    .sort({ checkIn: 1 });
  return bookings;
};

// ==========================================
// 14. GET BOOKING STATS
// Rapid calculation engine for the Dashboard Widgets (Today's check-ins, check-outs, etc)
// ==========================================
export const getBookingStats = async (propertyId) => {
  const property = await Property.findById(propertyId);
  if (!property) throw new AppError('Property not found', 404);

  // Time-boxing logic to isolate exactly "today"
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  // Execute 5 simultaneous database queries
  const totalBookings = await Booking.countDocuments({ property: propertyId });
  const activeBookings = await Booking.countDocuments({
    property: propertyId,
    bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] },
  });
  
  // Who is arriving today?
  const todayCheckIns = await Booking.countDocuments({
    property: propertyId,
    checkIn: { $gte: today, $lt: tomorrow },
    bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] },
  });
  
  // Who is leaving today?
  const todayCheckOuts = await Booking.countDocuments({
    property: propertyId,
    checkOut: { $gte: today, $lt: tomorrow },
    bookingStatus: { $in: ['checked-in', 'checked-out', 'completed'] },
  });
  
  // Who owes us money?
  const pendingPayments = await Booking.countDocuments({
    property: propertyId,
    paymentStatus: { $in: ['pending', 'partial'] },
    bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] },
  });

  return { totalBookings, activeBookings, todayCheckIns, todayCheckOuts, pendingPayments };
};

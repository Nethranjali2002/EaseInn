import Room from '../models/room.model.js'; 
import Property from '../models/property.model.js';
import Booking from '../models/booking.model.js'; 
import { AppError } from '../middlewares/error.middleware.js'; 
import { generateRoomCode } from '../utils/codeGenerator.js'; // Utility to create IDs like "RM-A1B2"

const VALID_STATUS_TRANSITIONS = {
  'available': ['booked', 'maintenance', 'blocked', 'cleaning'],
  'booked': ['occupied', 'available', 'maintenance'],
  'occupied': ['checked-out', 'maintenance'],
  'checked-out': ['cleaning', 'available', 'maintenance'],
  'cleaning': ['available', 'maintenance'],
  'maintenance': ['available', 'cleaning'],
  'blocked': ['available'],
};


// Checks if the requested status change is logically possible based on the dictionary above
const canRoomTransition = (from, to) => {
  if (from === to) return true;
  return VALID_STATUS_TRANSITIONS[from]?.includes(to) ?? false;
};



export const createRoom = async (propertyId, userId, data) => {
  const property = await Property.findById(propertyId);
  if (!property) throw new AppError('Property not found', 404);

  if (property.owner.toString() !== userId) {
    throw new AppError('You can only add rooms to your own properties', 403);
  }

  const existingRoom = await Room.findOne({ property: propertyId, roomNumber: data.roomNumber });
  if (existingRoom) throw new AppError('Room number already exists in this property', 409);

  const room = await Room.create({ ...data, property: propertyId, code: await generateRoomCode() });
  
  await Property.findByIdAndUpdate(propertyId, { $inc: { totalRooms: 1 } });
  return room;
};




export const getRooms = async (propertyId, { page = 1, limit = 20, status, roomType, search = '' }) => {
  const query = { property: propertyId, isActive: true };
  if (status) query.status = status;
  if (roomType) query.roomType = roomType;
  if (search) {
    query.$or = [
      { roomNumber: { $regex: search, $options: 'i' } },
      { name: { $regex: search, $options: 'i' } },
    ];
  }

  const total = await Room.countDocuments(query);
  const rooms = await Room.find(query)
    .sort({ floor: 1, roomNumber: 1 }) 
    .skip((page - 1) * limit)
    .limit(limit);

  // Find all rooms in this list that are currently marked as occupied or booked
  const roomIds = rooms.filter(r => r.status === 'booked' || r.status === 'occupied').map(r => r._id);

  // Bulk fetch the current active bookings for those specific rooms so we can display the guest's name on the frontend
  const activeBookingsMap = new Map();
  if (roomIds.length > 0) {
    const now = new Date();
    const activeBookings = await Booking.find({
      room: { $in: roomIds },
      bookingStatus: { $in: ['confirmed', 'checked-in'] },
      checkIn: { $lte: now },
      checkOut: { $gte: now },
    }).sort({ createdAt: -1 });

    for (const b of activeBookings) {
      const roomId = b.room.toString();
      if (!activeBookingsMap.has(roomId)) {
        activeBookingsMap.set(roomId, b);
      }
    }
  }

  // Smush the room data and the guest data together
  const enrichedRooms = rooms.map((r) => {
    let currentBooking = '-';
    let currentBookingId = null;

    if (r.status === 'booked' || r.status === 'occupied') {
      const activeBooking = activeBookingsMap.get(r._id.toString());
      if (activeBooking) {
        currentBooking = `${activeBooking.guest.name} (${activeBooking._id.toString().substring(18)})`;
        currentBookingId = activeBooking._id.toString();
      }
    }

    return {
      ...r.toObject(),
      currentBooking,
      currentBookingId,
    };
  });

  return { rooms: enrichedRooms, total, page, limit };
};



export const getRoomById = async (roomId) => {
  const room = await Room.findById(roomId);
  if (!room) throw new AppError('Room not found', 404);
  return room;
};





const ALLOWED_ROOM_UPDATES = ['roomNumber', 'roomType', 'name', 'capacity', 'basePrice', 'description', 'amenities', 'images', 'floor', 'status', 'isActive', 'seasonalRates', 'mealPlans'];


export const updateRoom = async (roomId, updates, userId, userRole) => {
  const room = await Room.findById(roomId);
  if (!room) throw new AppError('Room not found', 404);

  const property = await Property.findById(room.property);
  if (!property) throw new AppError('Property not found', 404);

  if (property.owner.toString() !== userId && userRole !== 'admin') {
    throw new AppError('You can only update rooms in your own properties', 403);
  }

  // Enforce the logical state machine (e.g. can't jump from 'available' to 'checked-out')
  if (updates.status && !canRoomTransition(room.status, updates.status)) {
    throw new AppError(`Cannot change room status from '${room.status}' to '${updates.status}'`, 409);
  }

  if (updates.status === 'available' && room.status !== 'available') {
    const activeBooking = await Booking.findOne({
      room: roomId,
      bookingStatus: { $in: ['confirmed', 'checked-in'] },
    });
    if (activeBooking) {
      throw new AppError('Cannot set room to available with an active booking', 409);
    }
  }

  const sanitized = {};
  for (const key of ALLOWED_ROOM_UPDATES) {
    if (updates[key] !== undefined) sanitized[key] = updates[key];
  }

  if (Object.keys(sanitized).length === 0) {
    throw new AppError('No valid fields to update', 400);
  }

  const updated = await Room.findByIdAndUpdate(roomId, { $set: sanitized }, { new: true, runValidators: true });
  return updated;
};






export const deleteRoom = async (roomId, userId, userRole) => {
  const room = await Room.findById(roomId);
  if (!room) throw new AppError('Room not found', 404);

  const property = await Property.findById(room.property);
  if (!property) throw new AppError('Property not found', 404);

  if (property.owner.toString() !== userId && userRole !== 'admin') {
    throw new AppError('You can only delete rooms in your own properties', 403);
  }

  // Cannot delete a room if it has upcoming reservations
  const activeBookings = await Booking.countDocuments({
    room: roomId,
    bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] },
  });
  if (activeBookings > 0) {
    throw new AppError(`Cannot delete room with ${activeBookings} active booking(s)`, 409);
  }

  await Room.findByIdAndUpdate(roomId, { isActive: false });
  
  await Property.findByIdAndUpdate(room.property, { $inc: { totalRooms: -1 } });
  return room;
};





export const getAvailableRooms = async (propertyId, checkIn, checkOut, roomType) => {
  const property = await Property.findById(propertyId);
  if (!property) throw new AppError('Property not found', 404);

  const query = { property: propertyId, isActive: true, status: 'available' };
  if (roomType) query.roomType = roomType;

  // First, fetch all active rooms in the hotel
  let rooms = await Room.find(query);

  if (checkIn && checkOut) {
    // Then, find all reservations that OVERLAP with the requested dates.
    const overlappingRoomIds = await Booking.distinct('room', {
      room: { $in: rooms.map(r => r._id) },
      bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] },
      checkIn: { $lt: new Date(checkOut) },
      checkOut: { $gt: new Date(checkIn) },
    });
    
    // Convert to a Set for blazing fast lookups
    const overlapSet = new Set(overlappingRoomIds.map(id => id.toString()));
    
    // Filter out the overlapping rooms. What remains is perfectly available for booking.
    rooms = rooms.filter(r => !overlapSet.has(r._id.toString()));
  }

  return rooms;
};

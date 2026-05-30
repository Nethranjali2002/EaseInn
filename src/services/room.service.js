import Room from '../models/room.model.js';
import Property from '../models/property.model.js';
import { AppError } from '../middlewares/error.middleware.js';

export const createRoom = async (propertyId, userId, data) => {
  const property = await Property.findById(propertyId);
  if (!property) throw new AppError('Property not found', 404);

  const existingRoom = await Room.findOne({ property: propertyId, roomNumber: data.roomNumber });
  if (existingRoom) throw new AppError('Room number already exists in this property', 409);

  const room = await Room.create({ ...data, property: propertyId });
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
  return { rooms, total, page, limit };
};

export const getRoomById = async (roomId) => {
  const room = await Room.findById(roomId);
  if (!room) throw new AppError('Room not found', 404);
  return room;
};

export const updateRoom = async (roomId, updates) => {
  const room = await Room.findByIdAndUpdate(roomId, { $set: updates }, { new: true, runValidators: true });
  if (!room) throw new AppError('Room not found', 404);
  return room;
};

export const deleteRoom = async (roomId) => {
  const room = await Room.findByIdAndUpdate(roomId, { isActive: false }, { new: true });
  if (!room) throw new AppError('Room not found', 404);
  await Property.findByIdAndUpdate(room.property, { $inc: { totalRooms: -1 } });
  return room;
};

export const getAvailableRooms = async (propertyId, checkIn, checkOut, roomType) => {
  const query = { property: propertyId, isActive: true, status: 'available' };
  if (roomType) query.roomType = roomType;

  const rooms = await Room.find(query);
  return rooms;
};

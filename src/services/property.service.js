import Property from '../models/property.model.js';
import Room from '../models/room.model.js';
import { AppError } from '../middlewares/error.middleware.js';

export const createProperty = async (ownerId, data) => {
  const property = await Property.create({ ...data, owner: ownerId });
  return property;
};

export const getProperties = async (ownerId, { page = 1, limit = 20, search = '' }) => {
  const query = { isActive: true };
  if (ownerId) query.owner = ownerId;
  if (search) {
    query.$or = [
      { name: { $regex: search, $options: 'i' } },
      { 'address.city': { $regex: search, $options: 'i' } },
    ];
  }
  const total = await Property.countDocuments(query);
  const properties = await Property.find(query)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);
  return { properties, total, page, limit };
};

export const getPropertyById = async (propertyId, userId) => {
  const query = { _id: propertyId };
  if (userId) query.owner = userId;
  const property = await Property.findOne(query);
  if (!property) throw new AppError('Property not found', 404);
  return property;
};

export const updateProperty = async (propertyId, userId, updates) => {
  const property = await Property.findOneAndUpdate(
    { _id: propertyId, owner: userId },
    { $set: updates },
    { new: true, runValidators: true }
  );
  if (!property) throw new AppError('Property not found', 404);
  return property;
};

export const deleteProperty = async (propertyId, userId) => {
  const property = await Property.findOneAndDelete({ _id: propertyId, owner: userId });
  if (!property) throw new AppError('Property not found', 404);
  await Room.deleteMany({ property: propertyId });
  return property;
};

export const getPropertyStats = async (propertyId) => {
  const totalRooms = await Room.countDocuments({ property: propertyId, isActive: true });
  const availableRooms = await Room.countDocuments({ property: propertyId, status: 'available', isActive: true });
  const bookedRooms = await Room.countDocuments({ property: propertyId, status: 'booked' });
  const maintenanceRooms = await Room.countDocuments({ property: propertyId, status: 'maintenance' });

  return {
    totalRooms,
    availableRooms,
    bookedRooms,
    maintenanceRooms,
    occupancyRate: totalRooms > 0 ? ((bookedRooms / totalRooms) * 100).toFixed(1) : 0,
  };
};

import Property from '../models/property.model.js';
import Room from '../models/room.model.js';
import Booking from '../models/booking.model.js';
import Payment from '../models/payment.model.js';
import Task from '../models/task.model.js';
import Feedback from '../models/feedback.model.js';
import Notification from '../models/notification.model.js';
import { AppError } from '../middlewares/error.middleware.js';
import { generatePropertyCode } from '../utils/codeGenerator.js';

export const createProperty = async (ownerId, data) => {
  const existing = await Property.findOne({
    name: { $regex: new RegExp(`^${data.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`), $options: 'i' },
    owner: ownerId,
  });
  if (existing) throw new AppError('A property with this name already exists', 409);

  const property = await Property.create({ ...data, owner: ownerId, code: await generatePropertyCode() });
  return property;
};

export const getProperties = async (ownerId, { page = 1, limit = 20, search = '' }) => {
  const query = {};
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

  const propertyIds = properties.map((p) => p._id);

  const [roomStats, activeBookingCounts, revenueResults] = await Promise.all([
    Room.aggregate([
      { $match: { property: { $in: propertyIds }, isActive: true } },
      {
        $group: {
          _id: '$property',
          totalRooms: { $sum: 1 },
          availableRooms: { $sum: { $cond: [{ $eq: ['$status', 'available'] }, 1, 0] } },
          bookedRooms: { $sum: { $cond: [{ $in: ['$status', ['booked', 'occupied']] }, 1, 0] } },
          maintenanceRooms: { $sum: { $cond: [{ $eq: ['$status', 'maintenance'] }, 1, 0] } },
        },
      },
    ]),
    Booking.aggregate([
      { $match: { property: { $in: propertyIds }, bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] } } },
      { $group: { _id: '$property', count: { $sum: 1 } } },
    ]),
    Payment.aggregate([
      {
        $match: {
          property: { $in: propertyIds },
          status: 'completed',
          type: { $ne: 'refund' },
          paidAt: { $gte: new Date(new Date().getFullYear(), new Date().getMonth(), 1) },
        },
      },
      { $group: { _id: '$property', total: { $sum: '$amount' } } },
    ]),
  ]);

  const roomStatsMap = new Map(roomStats.map((r) => [r._id.toString(), r]));
  const activeBookingMap = new Map(activeBookingCounts.map((b) => [b._id.toString(), b.count]));
  const revenueMap = new Map(revenueResults.map((r) => [r._id.toString(), r.total]));

  const enrichedProperties = properties.map((p) => {
    const stats = roomStatsMap.get(p._id.toString()) || { totalRooms: 0, availableRooms: 0, bookedRooms: 0, maintenanceRooms: 0 };
    const totalRooms = stats.totalRooms;
    const occupancyRate = totalRooms > 0 ? ((stats.bookedRooms / totalRooms) * 100).toFixed(1) : 0;

    return {
      ...p.toObject(),
      availableRooms: stats.availableRooms,
      occupancyRate: parseFloat(occupancyRate),
      activeBookings: activeBookingMap.get(p._id.toString()) || 0,
      revenueThisMonth: revenueMap.get(p._id.toString()) || 0,
    };
  });

  return { properties: enrichedProperties, total, page, limit };
};

export const getPropertyById = async (propertyId, userId) => {
  const query = { _id: propertyId };
  if (userId) query.owner = userId;
  const property = await Property.findOne(query);
  if (!property) throw new AppError('Property not found', 404);
  return property;
};

export const updateProperty = async (propertyId, userId, updates, expectedVersion) => {
  if (expectedVersion !== undefined) {
    const existing = await Property.findOne({ _id: propertyId, owner: userId });
    if (!existing) throw new AppError('Property not found', 404);
    if (existing.__v !== expectedVersion) {
      throw new AppError('Property has been modified by another user. Please refresh and try again', 409);
    }
  }

  if (updates.name) {
    const existing = await Property.findOne({
      _id: { $ne: propertyId },
      name: { $regex: new RegExp(`^${updates.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`), $options: 'i' },
      owner: userId,
    });
    if (existing) throw new AppError('A property with this name already exists', 409);
  }

  const property = await Property.findOneAndUpdate(
    { _id: propertyId, owner: userId },
    { $set: updates, $inc: { __v: 1 } },
    { new: true, runValidators: true }
  );
  if (!property) throw new AppError('Property not found', 404);
  return property;
};

export const deleteProperty = async (propertyId, userId) => {
  const property = await Property.findOne({ _id: propertyId, owner: userId });
  if (!property) throw new AppError('Property not found', 404);

  const activeBookings = await Booking.countDocuments({
    property: propertyId,
    bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] },
  });
  if (activeBookings > 0) {
    throw new AppError(`Cannot delete property with ${activeBookings} active booking(s). Cancel or complete them first.`, 409);
  }

  await Property.findOneAndDelete({ _id: propertyId, owner: userId });

  await Promise.all([
    Room.deleteMany({ property: propertyId }),
    Booking.deleteMany({ property: propertyId }),
    Payment.deleteMany({ property: propertyId }),
    Task.deleteMany({ property: propertyId }),
    Feedback.deleteMany({ property: propertyId }),
    Notification.deleteMany({ property: propertyId }),
  ]);

  return property;
};

export const getPropertyStats = async (propertyId) => {
  const property = await Property.findById(propertyId);
  if (!property) throw new AppError('Property not found', 404);

  const totalRooms = await Room.countDocuments({ property: propertyId, isActive: true });
  const availableRooms = await Room.countDocuments({ property: propertyId, status: 'available', isActive: true });
  const bookedRooms = await Room.countDocuments({ property: propertyId, status: 'booked' });
  const occupiedRooms = await Room.countDocuments({ property: propertyId, status: 'occupied' });
  const maintenanceRooms = await Room.countDocuments({ property: propertyId, status: 'maintenance' });

  const occupancyBasis = bookedRooms + occupiedRooms;
  const occupancyRate = totalRooms > 0 ? ((occupancyBasis / totalRooms) * 100).toFixed(1) : 0;

  return {
    totalRooms,
    availableRooms,
    bookedRooms,
    occupiedRooms,
    maintenanceRooms,
    occupancyRate: parseFloat(occupancyRate),
  };
};

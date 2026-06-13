import Property from '../models/property.model.js'; // DB Model for the hotel itself
import Room from '../models/room.model.js';
import Booking from '../models/booking.model.js';
import Payment from '../models/payment.model.js';
import Task from '../models/task.model.js';
import Feedback from '../models/feedback.model.js';
import Notification from '../models/notification.model.js';
import { AppError } from '../middlewares/error.middleware.js'; // Helper for throwing HTTP errors
import { generatePropertyCode } from '../utils/codeGenerator.js'; // Helper that makes a random string like "HTL-8B29"


// ==========================================
// 1. CREATE PROPERTY
// Used when an admin opens a brand new hotel
// ==========================================
export const createProperty = async (ownerId, data) => {
  // Check if this specific owner already has a hotel with this exact name (case-insensitive check)
  const existing = await Property.findOne({
    name: { $regex: new RegExp(`^${data.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`), $options: 'i' },
    owner: ownerId,
  });
  if (existing) throw new AppError('A property with this name already exists', 409);

  // Generate a unique 8-character ID code for this hotel, then save it
  const property = await Property.create({ ...data, owner: ownerId, code: await generatePropertyCode() });
  return property;
};


// ==========================================
// 2. GET PROPERTIES (With Aggregation)
// The massive query that powers the main Admin Dashboard
// ==========================================
export const getProperties = async (ownerId, { page = 1, limit = 20, search = '' }) => {
  // 1. Build the basic filter (Owner ID + Text Search)
  const query = {};
  if (ownerId) query.owner = ownerId;
  if (search) {
    query.$or = [
      { name: { $regex: search, $options: 'i' } },
      { 'address.city': { $regex: search, $options: 'i' } },
    ];
  }

  const total = await Property.countDocuments(query);
  
  // 2. Fetch the basic text data for the hotels
  const properties = await Property.find(query)
    .sort({ createdAt: -1 })
    .skip((page - 1) * limit)
    .limit(limit);

  const propertyIds = properties.map((p) => p._id);

  // 3. SUPER QUERY: Run 3 massive aggregations AT THE SAME TIME (Promise.all)
  // This is much faster than running them one by one.
  const [roomStats, activeBookingCounts, revenueResults] = await Promise.all([
    // A. Count up all the rooms across all these hotels, and split them by their current status
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
    
    // B. Count how many people are currently checked-in or about to check-in
    Booking.aggregate([
      { $match: { property: { $in: propertyIds }, bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] } } },
      { $group: { _id: '$property', count: { $sum: 1 } } },
    ]),
    
    // C. Add up all the money made THIS MONTH (status = completed, type != refund)
    Payment.aggregate([
      {
        $match: {
          property: { $in: propertyIds },
          status: 'completed',
          type: { $ne: 'refund' },
          // Only grab payments from the 1st of the current month onward
          paidAt: { $gte: new Date(new Date().getFullYear(), new Date().getMonth(), 1) },
        },
      },
      { $group: { _id: '$property', total: { $sum: '$amount' } } },
    ]),
  ]);

  // 4. Convert the arrays we got back into Javascript Maps (HashMaps). 
  // This makes it instantly fast to look up the stats for a specific property ID in the next step.
  const roomStatsMap = new Map(roomStats.map((r) => [r._id.toString(), r]));
  const activeBookingMap = new Map(activeBookingCounts.map((b) => [b._id.toString(), b.count]));
  const revenueMap = new Map(revenueResults.map((r) => [r._id.toString(), r.total]));

  // 5. Smush the basic hotel data together with all the math we just calculated
  const enrichedProperties = properties.map((p) => {
    const stats = roomStatsMap.get(p._id.toString()) || { totalRooms: 0, availableRooms: 0, bookedRooms: 0, maintenanceRooms: 0 };
    const totalRooms = stats.totalRooms;
    const occupancyRate = totalRooms > 0 ? ((stats.bookedRooms / totalRooms) * 100).toFixed(1) : 0;

    return {
      ...p.toObject(), // Convert from MongoDB document to standard JSON
      availableRooms: stats.availableRooms,
      occupancyRate: parseFloat(occupancyRate),
      activeBookings: activeBookingMap.get(p._id.toString()) || 0,
      revenueThisMonth: revenueMap.get(p._id.toString()) || 0,
    };
  });

  return { properties: enrichedProperties, total, page, limit };
};


// ==========================================
// 3. GET PROPERTY BY ID
// ==========================================
export const getPropertyById = async (propertyId, userId) => {
  const query = { _id: propertyId };
  if (userId) query.owner = userId; // Security: Ensure this user actually owns this property
  const property = await Property.findOne(query);
  if (!property) throw new AppError('Property not found', 404);
  return property;
};


// ==========================================
// 4. UPDATE PROPERTY
// Includes Concurrency Control (Versioning)
// ==========================================
export const updateProperty = async (propertyId, userId, updates, expectedVersion) => {
  // VERSIONING (Optimistic Concurrency Control):
  // If two managers have the settings page open at the same time, we don't want Manager B
  // to accidentally overwrite changes Manager A just made.
  // The frontend passes the `__v` (version) number it saw when it loaded the page.
  if (expectedVersion !== undefined) {
    const existing = await Property.findOne({ _id: propertyId, owner: userId });
    if (!existing) throw new AppError('Property not found', 404);
    
    if (existing.__v !== expectedVersion) {
      // If the database version is higher than what the frontend sent, someone else edited this hotel already.
      throw new AppError('Property has been modified by another user. Please refresh and try again', 409);
    }
  }

  // If they are changing the name, ensure they aren't renaming it to something they already own
  if (updates.name) {
    const existing = await Property.findOne({
      _id: { $ne: propertyId },
      name: { $regex: new RegExp(`^${updates.name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`), $options: 'i' },
      owner: userId,
    });
    if (existing) throw new AppError('A property with this name already exists', 409);
  }

  // Update the hotel, and explicitly increment the version `__v` by 1 so the concurrency check works next time
  const property = await Property.findOneAndUpdate(
    { _id: propertyId, owner: userId },
    { $set: updates, $inc: { __v: 1 } },
    { new: true, runValidators: true }
  );
  if (!property) throw new AppError('Property not found', 404);
  return property;
};


// ==========================================
// 5. DELETE PROPERTY (Dangerous)
// Wipes out an entire hotel and everything inside it
// ==========================================
export const deleteProperty = async (propertyId, userId) => {
  const property = await Property.findOne({ _id: propertyId, owner: userId });
  if (!property) throw new AppError('Property not found', 404);

  // You cannot delete a hotel if people are currently sleeping in it
  const activeBookings = await Booking.countDocuments({
    property: propertyId,
    bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] },
  });
  if (activeBookings > 0) {
    throw new AppError(`Cannot delete property with ${activeBookings} active booking(s). Cancel or complete them first.`, 409);
  }

  // Delete the hotel itself
  await Property.findOneAndDelete({ _id: propertyId, owner: userId });

  // CASCADING DELETE: Wipe out literally everything attached to this hotel
  // Run them all in parallel to save time
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


// ==========================================
// 6. GET PROPERTY STATS
// Basic room math for the frontend sidebars
// ==========================================
export const getPropertyStats = async (propertyId) => {
  const property = await Property.findById(propertyId);
  if (!property) throw new AppError('Property not found', 404);

  // Count exactly what state every room in the hotel is currently in
  const totalRooms = await Room.countDocuments({ property: propertyId, isActive: true });
  const availableRooms = await Room.countDocuments({ property: propertyId, status: 'available', isActive: true });
  const bookedRooms = await Room.countDocuments({ property: propertyId, status: 'booked' });
  const occupiedRooms = await Room.countDocuments({ property: propertyId, status: 'occupied' });
  const maintenanceRooms = await Room.countDocuments({ property: propertyId, status: 'maintenance' });

  // Occupancy includes both people who are here right now (occupied), and people arriving today (booked)
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

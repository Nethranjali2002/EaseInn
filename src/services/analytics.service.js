import Booking from '../models/booking.model.js';
import Payment from '../models/payment.model.js';
import Room from '../models/room.model.js';
import Task from '../models/task.model.js';
import Property from '../models/property.model.js';

export const getRevenueReport = async (propertyId, { startDate, endDate }) => {
  const match = { property: propertyId, status: 'completed' };
  if (startDate) match.paidAt = { $gte: new Date(startDate) };
  if (endDate) match.paidAt = { ...match.paidAt, $lte: new Date(endDate) };

  const revenue = await Payment.aggregate([
    { $match: match },
    {
      $group: {
        _id: { $dateToString: { format: '%Y-%m-%d', date: '$paidAt' } },
        total: { $sum: '$amount' },
        count: { $sum: 1 },
      },
    },
    { $sort: { _id: 1 } },
  ]);

  return revenue;
};

export const getOccupancyReport = async (propertyId, { startDate, endDate }) => {
  const rooms = await Room.countDocuments({ property: propertyId, isActive: true });
  const bookings = await Booking.find({
    property: propertyId,
    bookingStatus: { $in: ['confirmed', 'checked-in'] },
    checkIn: { $lte: new Date(endDate || Date.now()) },
    checkOut: { $gte: new Date(startDate || Date.now()) },
  });

  const occupiedNights = bookings.reduce((sum, b) => {
    const start = new Date(Math.max(new Date(b.checkIn).getTime(), new Date(startDate || b.checkIn).getTime()));
    const end = new Date(Math.min(new Date(b.checkOut).getTime(), new Date(endDate || b.checkOut).getTime()));
    return sum + Math.max(0, Math.ceil((end - start) / (1000 * 60 * 60 * 24)));
  }, 0);

  const totalDays = Math.ceil((new Date(endDate || Date.now()) - new Date(startDate || Date.now())) / (1000 * 60 * 60 * 24));
  const totalRoomNights = rooms * Math.max(1, totalDays);

  return {
    totalRooms: rooms,
    occupancyRate: totalRoomNights > 0 ? ((occupiedNights / totalRoomNights) * 100).toFixed(1) : 0,
    occupiedNights,
    totalRoomNights,
  };
};

export const getBookingTrends = async (propertyId, { months = 6 }) => {
  const startDate = new Date();
  startDate.setMonth(startDate.getMonth() - months);

  const trends = await Booking.aggregate([
    { $match: { property: propertyId, createdAt: { $gte: startDate } } },
    {
      $group: {
        _id: { $dateToString: { format: '%Y-%m', date: '$createdAt' } },
        total: { $sum: 1 },
        cancelled: { $sum: { $cond: [{ $eq: ['$bookingStatus', 'cancelled'] }, 1, 0] } },
        revenue: { $sum: '$pricing.totalAmount' },
      },
    },
    { $sort: { _id: 1 } },
  ]);

  return trends;
};

export const getTaskPerformance = async (propertyId) => {
  const performance = await Task.aggregate([
    { $match: { property: propertyId } },
    {
      $group: {
        _id: { $ifNull: ['$assignedTo', null] },
        total: { $sum: 1 },
        completed: { $sum: { $cond: [{ $eq: ['$status', 'completed'] }, 1, 0] } },
        overdue: {
          $sum: {
            $cond: [
              { $and: [{ $in: ['$status', ['open', 'in-progress']] }, { $lt: ['$dueDate', new Date()] }] },
              1,
              0,
            ],
          },
        },
        avgActualDuration: {
          $avg: {
            $cond: [{ $eq: ['$status', 'completed'] }, '$actualDuration', null],
          },
        },
        avgEstimatedDuration: {
          $avg: '$estimatedDuration',
        },
        totalActualDuration: {
          $sum: {
            $cond: [{ $eq: ['$status', 'completed'] }, '$actualDuration', 0],
          },
        },
      },
    },
    {
      $lookup: {
        from: 'users',
        localField: '_id',
        foreignField: '_id',
        as: 'assignee',
      },
    },
    {
      $unwind: {
        path: '$assignee',
        preserveNullAndEmptyArrays: true,
      },
    },
    {
      $project: {
        _id: 1,
        assigneeName: { $ifNull: ['$assignee.name', 'Unassigned'] },
        assigneeEmail: { $ifNull: ['$assignee.email', ''] },
        total: 1,
        completed: 1,
        overdue: 1,
        completionRate: {
          $cond: [{ $gt: ['$total', 0] }, { $multiply: [{ $divide: ['$completed', '$total'] }, 100] }, 0],
        },
        avgActualDuration: { $round: [{ $ifNull: ['$avgActualDuration', 0] }, 1] },
        avgEstimatedDuration: { $round: [{ $ifNull: ['$avgEstimatedDuration', 0] }, 1] },
        totalActualDuration: { $round: [{ $ifNull: ['$totalActualDuration', 0] }, 1] },
      },
    },
  ]);

  return performance;
};

export const getRoomTypePerformance = async (propertyId) => {
  const performance = await Booking.aggregate([
    { $match: { property: propertyId, bookingStatus: { $ne: 'cancelled' } } },
    {
      $group: {
        _id: '$roomType',
        bookings: { $sum: 1 },
        revenue: { $sum: '$pricing.totalAmount' },
        avgGuests: { $avg: '$numberOfGuests' },
      },
    },
    { $sort: { revenue: -1 } },
  ]);

  return performance;
};

import Booking from '../models/booking.model.js';
import Payment from '../models/payment.model.js';
import Room from '../models/room.model.js';
import Property from '../models/property.model.js';
import { sendSuccess } from '../utils/response.util.js';

export const getConsolidatedReport = async (req, res, next) => {
  try {
    const properties = await Property.find({ owner: req.user.sub, isActive: true });
    const propertyIds = properties.map(p => p._id);

    const totalProperties = properties.length;
    const totalRooms = await Room.countDocuments({ property: { $in: propertyIds }, isActive: true });
    const totalBookings = await Booking.countDocuments({ property: { $in: propertyIds } });
    const activeBookings = await Booking.countDocuments({ property: { $in: propertyIds }, bookingStatus: { $in: ['confirmed', 'checked-in'] } });

    const revenue = await Payment.aggregate([
      { $match: { property: { $in: propertyIds }, status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: '$property', total: { $sum: '$amount' } } },
    ]);

    const totalRevenue = revenue.reduce((sum, r) => sum + r.total, 0);

    const propertyPerformance = properties.map(p => {
      const rev = revenue.find(r => r._id.toString() === p._id.toString());
      return { _id: p._id, name: p.name, city: p.address?.city, revenue: rev?.total || 0 };
    }).sort((a, b) => b.revenue - a.revenue);

    return sendSuccess(res, { data: { totalProperties, totalRooms, totalBookings, activeBookings, totalRevenue, propertyPerformance } });
  } catch (err) { return next(err); }
};

export const getAIPricingSuggestions = async (req, res, next) => {
  try {
    const { propertyId } = req.params;
    const rooms = await Room.find({ property: propertyId, isActive: true });

    const bookings = await Booking.find({
      property: propertyId,
      bookingStatus: { $in: ['confirmed', 'checked-in', 'checked-out'] },
      createdAt: { $gte: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000) },
    });

    const now = new Date();
    const dayOfWeek = now.getDay();
    const month = now.getMonth();
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 5 || dayOfWeek === 6;
    const peakMonths = [11, 0, 1, 6, 7];
    const isPeakSeason = peakMonths.includes(month);

    const recentBookings = bookings.length;
    const recentBookingsPerWeek = recentBookings / 13;

    const totalRevenue = bookings.reduce((sum, b) => sum + (b.pricing?.totalAmount || 0), 0);
    const avgRevenuePerBooking = recentBookings > 0 ? totalRevenue / recentBookings : 0;

    const suggestions = rooms.map(room => {
      const basePrice = room.basePrice;
      let demandMultiplier = 1.0;

      if (recentBookingsPerWeek > 3) demandMultiplier += 0.25;
      else if (recentBookingsPerWeek > 2) demandMultiplier += 0.15;
      else if (recentBookingsPerWeek > 1) demandMultiplier += 0.08;
      else if (recentBookingsPerWeek < 0.5) demandMultiplier -= 0.12;

      if (isWeekend) demandMultiplier += 0.15;
      if (isPeakSeason) demandMultiplier += 0.20;

      const occupancyRate = recentBookings / (rooms.length * 13 * 7) * 100;
      if (occupancyRate > 80) demandMultiplier += 0.15;
      else if (occupancyRate > 60) demandMultiplier += 0.08;
      else if (occupancyRate < 30) demandMultiplier -= 0.10;

      const suggestedPrice = Math.round(basePrice * demandMultiplier);
      const lowSeasonPrice = Math.round(basePrice * 0.85);
      const highDemandPrice = Math.round(basePrice * 1.45);

      return {
        roomId: room._id,
        roomNumber: room.roomNumber,
        roomType: room.roomType,
        currentPrice: basePrice,
        suggestedPrice,
        lowSeasonPrice,
        highDemandPrice,
        demandMultiplier: Math.round(demandMultiplier * 100) / 100,
        factors: {
          demand: recentBookingsPerWeek > 2 ? 'high' : recentBookingsPerWeek > 1 ? 'medium' : 'low',
          weekend: isWeekend,
          peakSeason: isPeakSeason,
          occupancyRate: Math.round(occupancyRate),
        },
        confidence: Math.min(0.95, 0.5 + (recentBookings / 50)),
        basedOn: `${recentBookings} bookings in last 90 days`,
      };
    });

    return sendSuccess(res, { data: { suggestions, generatedAt: now.toISOString() } });
  } catch (err) { return next(err); }
};

export const getDemandForecast = async (req, res, next) => {
  try {
    const { propertyId } = req.params;

    const monthlyBookings = await Booking.aggregate([
      { $match: { property: propertyId, createdAt: { $gte: new Date(Date.now() - 365 * 24 * 60 * 60 * 1000) } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m', date: '$createdAt' } }, count: { $sum: 1 }, revenue: { $sum: '$pricing.totalAmount' } } },
      { $sort: { _id: 1 } },
    ]);

    const monthlyRevenue = await Payment.aggregate([
      { $match: { property: propertyId, status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m', date: '$paidAt' } }, total: { $sum: '$amount' } } },
      { $sort: { _id: 1 } },
    ]);

    const bookings = monthlyBookings.map(m => m.count);
    const avgMonthly = bookings.length > 0 ? bookings.reduce((a, b) => a + b, 0) / bookings.length : 0;

    let trend = 0;
    if (bookings.length >= 3) {
      const recent = bookings.slice(-3);
      const older = bookings.slice(0, 3);
      const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
      const olderAvg = older.reduce((a, b) => a + b, 0) / older.length;
      trend = olderAvg > 0 ? (recentAvg - olderAvg) / olderAvg : 0;
    }

    const forecast = [];
    for (let i = 1; i <= 3; i++) {
      const date = new Date();
      date.setMonth(date.getMonth() + i);
      const month = date.toISOString().slice(0, 7);
      const predicted = Math.round(avgMonthly * (1 + trend) * (1 + i * 0.02));
      forecast.push({
        month,
        predictedBookings: Math.max(0, predicted),
        predictedRevenue: Math.round(predicted * (monthlyRevenue.length > 0 ? monthlyRevenue.reduce((s, m) => s + m.total, 0) / monthlyRevenue.length / Math.max(1, avgMonthly) : 0)),
        confidence: Math.max(0.4, Math.min(0.9, 0.5 + bookings.length * 0.04 - i * 0.08)),
      });
    }

    return sendSuccess(res, {
      data: {
        historical: monthlyBookings.map(m => ({ month: m._id, bookings: m.count, revenue: m.revenue })),
        averageMonthly: Math.round(avgMonthly),
        trend: Math.round(trend * 100) + '%',
        forecast,
        generatedAt: new Date().toISOString(),
      },
    });
  } catch (err) { return next(err); }
};

export const getConsolidatedCalendar = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const properties = await Property.find({ owner: req.user.sub, isActive: true });
    const propertyIds = properties.map(p => p._id);

    const bookings = await Booking.find({
      property: { $in: propertyIds },
      checkIn: { $lte: new Date(endDate || Date.now()) },
      checkOut: { $gte: new Date(startDate || Date.now()) },
      bookingStatus: { $in: ['confirmed', 'checked-in'] },
    })
      .populate('room', 'roomNumber roomType')
      .populate('property', 'name')
      .sort({ checkIn: 1 });

    return sendSuccess(res, { data: { bookings, properties: properties.map(p => ({ _id: p._id, name: p.name })) } });
  } catch (err) { return next(err); }
};

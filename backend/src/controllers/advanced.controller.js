import Booking from '../models/booking.model.js'; // Database model for reservations
import Payment from '../models/payment.model.js'; // Database model for money
import Room from '../models/room.model.js'; // Database model for physical hotel rooms
import Property from '../models/property.model.js'; // Database model for whole hotels
import { sendSuccess } from '../utils/response.util.js'; // Helper for formatting JSON


// ==========================================
// 1. GET CONSOLIDATED REPORT
// Generates a massive bird's-eye view for an Admin who owns multiple hotels
// ==========================================
export const getConsolidatedReport = async (req, res, next) => {
  try {
    // Find all active properties owned by this specific admin
    const properties = await Property.find({ owner: req.user.sub, isActive: true });
    const propertyIds = properties.map(p => p._id);

    // Count every single asset and active booking across all their properties
    const totalProperties = properties.length;
    const totalRooms = await Room.countDocuments({ property: { $in: propertyIds }, isActive: true });
    const totalBookings = await Booking.countDocuments({ property: { $in: propertyIds } });
    const activeBookings = await Booking.countDocuments({ property: { $in: propertyIds }, bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in'] } });

    // Use MongoDB aggregation to sum up all completed, non-refunded payments group by property
    const revenue = await Payment.aggregate([
      { $match: { property: { $in: propertyIds }, status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: '$property', total: { $sum: '$amount' } } },
    ]);

    // Add up the totals from the aggregation to get the master total revenue
    const totalRevenue = revenue.reduce((sum, r) => sum + r.total, 0);

    // Format a nice leaderboard of properties sorted by which one made the most money
    const propertyPerformance = properties.map(p => {
      const rev = revenue.find(r => r._id.toString() === p._id.toString());
      return { _id: p._id, name: p.name, city: p.address?.city, revenue: rev?.total || 0 };
    }).sort((a, b) => b.revenue - a.revenue);

    return sendSuccess(res, { data: { totalProperties, totalRooms, totalBookings, activeBookings, totalRevenue, propertyPerformance } });
  } catch (err) { return next(err); }
};


// ==========================================
// 2. GET AI PRICING SUGGESTIONS
// Calculates if a hotel manager should raise or lower room prices based on recent demand
// ==========================================
export const getAIPricingSuggestions = async (req, res, next) => {
  try {
    const { propertyId } = req.params;
    
    // Fetch all active rooms for this specific hotel
    const rooms = await Room.find({ property: propertyId, isActive: true });

    // Look at the last 90 days of successful bookings to gauge recent popularity
    const bookings = await Booking.find({
      property: propertyId,
      bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in', 'checked-out', 'completed'] },
      createdAt: { $gte: new Date(Date.now() - 90 * 24 * 60 * 60 * 1000) },
    });

    // Check if right now is a weekend or a typical holiday peak season
    const now = new Date();
    const dayOfWeek = now.getDay();
    const month = now.getMonth();
    const isWeekend = dayOfWeek === 0 || dayOfWeek === 5 || dayOfWeek === 6;
    const peakMonths = [11, 0, 1, 6, 7]; // Dec, Jan, Feb, July, Aug
    const isPeakSeason = peakMonths.includes(month);

    // Calculate how many bookings are happening per week on average
    const recentBookings = bookings.length;
    const recentBookingsPerWeek = recentBookings / 13; // 90 days is roughly 13 weeks

    const totalRevenue = bookings.reduce((sum, b) => sum + (b.pricing?.totalAmount || 0), 0);
    const avgRevenuePerBooking = recentBookings > 0 ? totalRevenue / recentBookings : 0;

    // Loop through every room and generate a specific price suggestion for it
    const suggestions = rooms.map(room => {
      const basePrice = room.basePrice;
      let demandMultiplier = 1.0;

      // Bump up the price multiplier if the hotel is getting lots of bookings per week
      if (recentBookingsPerWeek > 3) demandMultiplier += 0.25;
      else if (recentBookingsPerWeek > 2) demandMultiplier += 0.15;
      else if (recentBookingsPerWeek > 1) demandMultiplier += 0.08;
      else if (recentBookingsPerWeek < 0.5) demandMultiplier -= 0.12;

      // Bump up the price if it's the weekend or peak season
      if (isWeekend) demandMultiplier += 0.15;
      if (isPeakSeason) demandMultiplier += 0.20;

      // Check the overall occupancy percentage. If it's mostly full, raise prices. If empty, lower them.
      const occupancyRate = recentBookings / (rooms.length * 13 * 7) * 100;
      if (occupancyRate > 80) demandMultiplier += 0.15;
      else if (occupancyRate > 60) demandMultiplier += 0.08;
      else if (occupancyRate < 30) demandMultiplier -= 0.10;

      // Generate the final suggested numbers to show the manager on the frontend
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
        // The more data we have (bookings), the more "confident" the AI is in this number
        confidence: Math.min(0.95, 0.5 + (recentBookings / 50)),
        basedOn: `${recentBookings} bookings in last 90 days`,
      };
    });

    return sendSuccess(res, { data: { suggestions, generatedAt: now.toISOString() } });
  } catch (err) { return next(err); }
};


// ==========================================
// 3. GET DEMAND FORECAST
// Predicts how many bookings and revenue the hotel will make in the next 3 months
// ==========================================
export const getDemandForecast = async (req, res, next) => {
  try {
    const { propertyId } = req.params;

    // Aggregate the last 365 days of bookings, grouping them by Month (e.g. "2023-10")
    const monthlyBookings = await Booking.aggregate([
      { $match: { property: propertyId, createdAt: { $gte: new Date(Date.now() - 365 * 24 * 60 * 60 * 1000) } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m', date: '$createdAt' } }, count: { $sum: 1 }, revenue: { $sum: '$pricing.totalAmount' } } },
      { $sort: { _id: 1 } },
    ]);

    // Aggregate the last 365 days of payments, grouping them by Month
    const monthlyRevenue = await Payment.aggregate([
      { $match: { property: propertyId, status: 'completed', type: { $ne: 'refund' } } },
      { $group: { _id: { $dateToString: { format: '%Y-%m', date: '$paidAt' } }, total: { $sum: '$amount' } } },
      { $sort: { _id: 1 } },
    ]);

    // Find the mathematical average of how many bookings happen per month
    const bookings = monthlyBookings.map(m => m.count);
    const avgMonthly = bookings.length > 0 ? bookings.reduce((a, b) => a + b, 0) / bookings.length : 0;

    // Calculate a "trend" by comparing the last 3 months vs the 3 months before that
    let trend = 0;
    if (bookings.length >= 3) {
      const recent = bookings.slice(-3);
      const older = bookings.slice(0, 3);
      const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
      const olderAvg = older.reduce((a, b) => a + b, 0) / older.length;
      trend = olderAvg > 0 ? (recentAvg - olderAvg) / olderAvg : 0;
    }

    // Generate a 3-month forecast
    const forecast = [];
    for (let i = 1; i <= 3; i++) {
      const date = new Date();
      date.setMonth(date.getMonth() + i);
      const month = date.toISOString().slice(0, 7);
      
      // Predict the bookings using the historical average, modified by the recent upward/downward trend
      const predicted = Math.round(avgMonthly * (1 + trend) * (1 + i * 0.02));
      
      forecast.push({
        month,
        predictedBookings: Math.max(0, predicted),
        // Predict the revenue by multiplying predicted bookings by historical average revenue per booking
        predictedRevenue: Math.round(predicted * (monthlyRevenue.length > 0 ? monthlyRevenue.reduce((s, m) => s + m.total, 0) / monthlyRevenue.length / Math.max(1, avgMonthly) : 0)),
        confidence: Math.max(0.4, Math.min(0.9, 0.5 + bookings.length * 0.04 - i * 0.08)),
      });
    }

    // Send the history, the trend analysis, and the 3-month future forecast back to the dashboard
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


// ==========================================
// 4. GET CONSOLIDATED CALENDAR
// Fetches all bookings across ALL properties for an admin's master calendar view
// ==========================================
export const getConsolidatedCalendar = async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const properties = await Property.find({ owner: req.user.sub, isActive: true });
    const propertyIds = properties.map(p => p._id);

    // Fetch every single booking that overlaps with the requested date range, across any property this admin owns
    const bookings = await Booking.find({
      property: { $in: propertyIds },
      checkIn: { $lte: new Date(endDate || Date.now()) },
      checkOut: { $gte: new Date(startDate || Date.now()) },
      bookingStatus: { $in: ['pending-payment', 'confirmed', 'checked-in', 'checked-out', 'completed'] },
    })
      .populate('room', 'roomNumber roomType')
      .populate('property', 'name')
      .sort({ checkIn: 1 });

    return sendSuccess(res, { data: { bookings, properties: properties.map(p => ({ _id: p._id, name: p.name })) } });
  } catch (err) { return next(err); }
};

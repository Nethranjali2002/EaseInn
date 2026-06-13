import AuditLog from '../models/auditLog.model.js'; // Imports the Mongoose Model representing the security log database
import { sendSuccess } from '../utils/response.util.js'; // Helper for formatting standard JSON responses

// ==========================================
// 1. GET AUDIT LOGS (Admin Dashboard)
// Fetches the secure paper-trail of every action performed by staff.
// ==========================================
export const getAuditLogs = async (req, res, next) => {
  try {
    // Extract pagination and filters from the query string (e.g., ?action=delete&entity=Room)
    const { page = 1, limit = 50, entity, action } = req.query;
    
    // Build an empty MongoDB query object
    const query = {};
    
    // If the admin wants to filter by a specific entity (like 'Property' or 'User'), add it to the query
    if (entity) query.entity = entity;
    
    // If the admin wants to filter by a specific action (like 'delete' or 'update'), add it to the query
    if (action) query.action = action;

    // Count exactly how many total logs match this query (useful for building pagination buttons on the frontend)
    const total = await AuditLog.countDocuments(query);
    
    // Fetch the actual log records from MongoDB
    const logs = await AuditLog.find(query)
      // Populate grabs the actual User object (name, email) instead of just showing a random User ID string
      .populate('user', 'name email role property')
      // Populate grabs the actual Property name instead of just its ID string
      .populate('property', 'name')
      // Sort the logs backwards by time so the newest actions appear at the top of the table
      .sort({ createdAt: -1 })
      // Skip the previous pages (e.g., if on page 2 with limit 50, skip the first 50 results)
      .skip((parseInt(page) - 1) * parseInt(limit))
      // Limit the results so we don't crash the server trying to send 10,000 logs at once
      .limit(parseInt(limit));

    // Send the securely fetched logs back to the Admin Dashboard
    return sendSuccess(res, { data: { logs, total, page: parseInt(page), limit: parseInt(limit) } });
  } catch (err) { 
    // Catch any DB errors and send to the global handler
    return next(err); 
  }
};

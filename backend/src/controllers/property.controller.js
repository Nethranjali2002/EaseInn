import * as propertyService from '../services/property.service.js'; // Imports the Brain handling Property/Hotel entity logic
import { sendSuccess } from '../utils/response.util.js'; // Helper to format JSON response
import { logAudit } from '../utils/audit.util.js'; // Records major actions (like deleting a property) for accountability


// ==========================================
// 1. PRESERVE VERSION (Concurrency Control)
// Prevents two managers from overwriting each other's edits.
// ==========================================
export const preserveVersion = (req, _res, next) => {
  // If the frontend sends a '__v' (version) number, save it to the request object.
  // The service will check this number to ensure the property wasn't modified by someone else first.
  if (req.body && typeof req.body.__v === 'number') {
    req._expectedVersion = req.body.__v;
  }
  next();
};


// ==========================================
// 2. CREATE PROPERTY
// ==========================================
export const createProperty = async (req, res, next) => {
  try {
    // Pass the Admin's ID and the raw property data (name, address, settings) to the Service
    const property = await propertyService.createProperty(req.user.sub, req.body);
    
    // Log the creation of this new hotel/resort in the audit trails
    await logAudit({ user: req.user.sub, action: 'create', entity: 'Property', entityId: property._id, description: `Created property: ${property.name}`, ip: req.ip, userAgent: req.get('user-agent') });
    
    return sendSuccess(res, { statusCode: 201, message: 'Property created', data: { property } });
  } catch (err) { return next(err); }
};


// ==========================================
// 3. GET PROPERTIES
// ==========================================
export const getProperties = async (req, res, next) => {
  try {
    const { page, limit, search } = req.query;
    
    // If the user is an Admin, they can see ALL properties. 
    // If they are a Manager, they can only see properties assigned to them.
    const isAdmin = req.user.role === 'admin';
    const ownerId = isAdmin ? req.user.sub : null;
    
    // Pass the ownerId to the Service to enforce data isolation (Multi-Tenancy)
    const result = await propertyService.getProperties(ownerId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, search });
    
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};


// ==========================================
// 4. GET PROPERTY BY ID
// ==========================================
export const getPropertyById = async (req, res, next) => {
  try {
    const isAdmin = req.user.role === 'admin';
    // Fetches the property details, but the Service will block the request if a Manager tries to view a property they don't own
    const property = await propertyService.getPropertyById(req.params.id, isAdmin ? req.user.sub : null);
    return sendSuccess(res, { data: { property } });
  } catch (err) { return next(err); }
};


// ==========================================
// 5. UPDATE PROPERTY
// ==========================================
export const updateProperty = async (req, res, next) => {
  try {
    // Pass the property ID, the user making the edit, the new data, and the expected version number
    const property = await propertyService.updateProperty(req.params.id, req.user.sub, req.body, req._expectedVersion);
    
    // Log the exact update action
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Property', entityId: property._id, description: `Updated property: ${property.name}`, ip: req.ip });
    
    return sendSuccess(res, { message: 'Property updated', data: { property } });
  } catch (err) { return next(err); }
};


// ==========================================
// 6. DELETE PROPERTY
// ==========================================
export const deleteProperty = async (req, res, next) => {
  try {
    // Permanently deletes the property (and usually triggers cascade deletes for its rooms/bookings in the Service)
    await propertyService.deleteProperty(req.params.id, req.user.sub);
    
    await logAudit({ user: req.user.sub, action: 'delete', entity: 'Property', entityId: req.params.id, description: 'Deleted property', ip: req.ip });
    
    return sendSuccess(res, { message: 'Property deleted' });
  } catch (err) { return next(err); }
};


// ==========================================
// 7. GET PROPERTY STATS
// ==========================================
export const getPropertyStats = async (req, res, next) => {
  try {
    // Fetches aggregated dashboard stats specifically for this single property (Total Rooms, Staff count, etc.)
    const stats = await propertyService.getPropertyStats(req.params.id);
    return sendSuccess(res, { data: stats });
  } catch (err) { return next(err); }
};

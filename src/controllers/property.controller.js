import * as propertyService from '../services/property.service.js';
import { sendSuccess } from '../utils/response.util.js';
import { logAudit } from '../utils/audit.util.js';

export const createProperty = async (req, res, next) => {
  try {
    const property = await propertyService.createProperty(req.user.sub, req.body);
    await logAudit({ user: req.user.sub, action: 'create', entity: 'Property', entityId: property._id, description: `Created property: ${property.name}`, ip: req.ip, userAgent: req.get('user-agent') });
    return sendSuccess(res, { statusCode: 201, message: 'Property created', data: { property } });
  } catch (err) { return next(err); }
};

export const getProperties = async (req, res, next) => {
  try {
    const { page, limit, search } = req.query;
    const isAdmin = req.user.role === 'admin';
    const ownerId = isAdmin ? req.user.sub : null;
    const result = await propertyService.getProperties(ownerId, { page: parseInt(page) || 1, limit: parseInt(limit) || 20, search });
    return sendSuccess(res, { data: result });
  } catch (err) { return next(err); }
};

export const getPropertyById = async (req, res, next) => {
  try {
    const isAdmin = req.user.role === 'admin';
    const property = await propertyService.getPropertyById(req.params.id, isAdmin ? req.user.sub : null);
    return sendSuccess(res, { data: { property } });
  } catch (err) { return next(err); }
};

export const updateProperty = async (req, res, next) => {
  try {
    const property = await propertyService.updateProperty(req.params.id, req.user.sub, req.body);
    await logAudit({ user: req.user.sub, action: 'update', entity: 'Property', entityId: property._id, description: `Updated property: ${property.name}`, ip: req.ip });
    return sendSuccess(res, { message: 'Property updated', data: { property } });
  } catch (err) { return next(err); }
};

export const deleteProperty = async (req, res, next) => {
  try {
    await propertyService.deleteProperty(req.params.id, req.user.sub);
    await logAudit({ user: req.user.sub, action: 'delete', entity: 'Property', entityId: req.params.id, description: 'Deleted property', ip: req.ip });
    return sendSuccess(res, { message: 'Property deleted' });
  } catch (err) { return next(err); }
};

export const getPropertyStats = async (req, res, next) => {
  try {
    const stats = await propertyService.getPropertyStats(req.params.id);
    return sendSuccess(res, { data: stats });
  } catch (err) { return next(err); }
};

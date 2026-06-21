import AuditLog from '../models/auditLog.model.js';
import { sendSuccess } from '../utils/response.util.js';

export const getAuditLogs = async (req, res, next) => {
  try {
    const { page = 1, limit = 50, entity, action } = req.query;
    const query = {};
    if (entity) query.entity = entity;
    if (action) query.action = action;

    const total = await AuditLog.countDocuments(query);
    const logs = await AuditLog.find(query)
      .populate('user', 'name email role property')
      .populate('property', 'name')
      .sort({ createdAt: -1 })
      .skip((parseInt(page) - 1) * parseInt(limit))
      .limit(parseInt(limit));

    return sendSuccess(res, { data: { logs, total, page: parseInt(page), limit: parseInt(limit) } });
  } catch (err) { return next(err); }
};

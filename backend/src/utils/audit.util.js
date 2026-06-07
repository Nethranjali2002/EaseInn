import AuditLog from '../models/auditLog.model.js';

export const logAudit = async ({
  user,
  action,
  entity,
  entityId,
  changes,
  description,
  ip,
  userAgent,
  property,
  status = 'success',
}) => {
  try {
    await AuditLog.create({
      user,
      action,
      entity,
      entityId,
      changes,
      description,
      ip,
      userAgent,
      property,
      status,
    });
  } catch (error) {
    // Silent fail - audit logging should not break main flow
  }
};

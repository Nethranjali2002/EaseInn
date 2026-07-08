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
    // Attempt to save the paper trail to the database
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
  }
};

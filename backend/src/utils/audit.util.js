import AuditLog from '../models/auditLog.model.js'; // The database model representing a permanent, un-deletable history log


// ==========================================
// 1. LOG AUDIT
// A centralized function used by all controllers to record critical actions (like deleting users or changing passwords).
// This creates a "paper trail" so administrators can figure out who did what, and when.
// ==========================================
export const logAudit = async ({
  user,        // The ID of the person performing the action
  action,      // A short string describing the action (e.g., 'DELETE_USER')
  entity,      // What type of thing was affected (e.g., 'User', 'Booking')
  entityId,    // The specific database ID of the thing that was affected
  changes,     // Optional: An object showing what the data looked like before and after the edit
  description, // A human-readable sentence explaining the event (e.g., "Admin deleted John's account")
  ip,          // The IP address of the person who clicked the button
  userAgent,   // The browser/device they were using (e.g., "Chrome on Windows")
  property,    // The hotel ID this action took place in (if applicable)
  status = 'success', // Did the action succeed, or did it throw an error?
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
    // IMPORTANT ARCHITECTURAL DECISION: Silent Fail
    // If the database fails to save the audit log (e.g. database is overloaded), 
    // we DO NOT want to crash the user's actual action (like checking in a guest). 
    // We swallow the error so the main business logic continues uninterrupted.
  }
};

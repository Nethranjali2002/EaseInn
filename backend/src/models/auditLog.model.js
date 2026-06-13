import mongoose from 'mongoose';

// ==========================================
// AUDIT LOG SCHEMA
// The "Paper Trail" table. A permanent, read-only history of every major action taken in the system.
// Crucial for security investigations (e.g. "Who deleted this booking?")
// ==========================================
const auditLogSchema = new mongoose.Schema(
  {
    // The specific staff member who performed the action
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true, // Indexed because we frequently search "Show me everything John did today"
    },
    
    // Broad categorization of WHAT they did
    action: {
      type: String,
      required: true,
      enum: [
        'login', 'logout', 'register', 'create', 'update', 
        'delete', 'view', 'export', 'payment', 'booking', 
        'task', 'config', 'other',
      ],
    },
    
    // Specifically WHICH table they modified (e.g. "Booking", "Room")
    entity: {
      type: String,
      required: true,
      trim: true,
    },
    
    // The exact database ID of the thing they modified
    entityId: {
      type: mongoose.Schema.Types.ObjectId,
    },
    
    // A snapshot of the data before and after they touched it. 
    // Uses `Mixed` type because we don't know the shape of the data in advance (a Room object looks different from a Booking object).
    changes: {
      before: { type: mongoose.Schema.Types.Mixed },
      after: { type: mongoose.Schema.Types.Mixed },
    },
    
    // A human-readable sentence explaining the action (e.g. "Manager changed room price from $100 to $120")
    description: {
      type: String,
      trim: true,
      maxlength: 500,
    },
    
    // The IP address of their computer (useful for tracking down hackers)
    ip: {
      type: String,
      trim: true,
    },
    
    // The browser and device they used (e.g. "Chrome 114 on Windows 10")
    userAgent: {
      type: String,
      trim: true,
    },
    
    // If the action was specific to a hotel branch, log which one
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
    },
    
    // Did the action succeed, or did it fail/crash?
    status: {
      type: String,
      enum: ['success', 'failure'],
      default: 'success',
    },
  },
  {
    timestamps: true, // Automatically records EXACTLY when the action happened
  }
);

// Database Indexes for Speed Optimization
auditLogSchema.index({ user: 1, createdAt: -1 });     // Speeds up "Show me recent actions by User X"
auditLogSchema.index({ entity: 1, entityId: 1 });     // Speeds up "Show me the entire history of this specific Booking"
auditLogSchema.index({ property: 1, createdAt: -1 }); // Speeds up "Show me all recent activity at the Downtown Hotel branch"
auditLogSchema.index({ action: 1, createdAt: -1 });   // Speeds up "Show me all recent 'delete' actions across the system"

const AuditLog = mongoose.model('AuditLog', auditLogSchema);

export default AuditLog;

import mongoose from 'mongoose';


const auditLogSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true, 
    },
    
    action: {
      type: String,
      required: true,
      enum: [
        'login', 'logout', 'register', 'create', 'update', 
        'delete', 'view', 'export', 'payment', 'booking', 
        'task', 'config', 'other',
      ],
    },
    
    entity: {
      type: String,
      required: true,
      trim: true,
    },
    
    entityId: {
      type: mongoose.Schema.Types.ObjectId,
    },
    
    changes: {
      before: { type: mongoose.Schema.Types.Mixed },
      after: { type: mongoose.Schema.Types.Mixed },
    },
    
    description: {
      type: String,
      trim: true,
      maxlength: 500,
    },
    
    ip: {
      type: String,
      trim: true,
    },
    
    userAgent: {
      type: String,
      trim: true,
    },
    
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
    },
    
    status: {
      type: String,
      enum: ['success', 'failure'],
      default: 'success',
    },
  },
  {
    timestamps: true, 
  }
);

auditLogSchema.index({ user: 1, createdAt: -1 });    
auditLogSchema.index({ entity: 1, entityId: 1 });     
auditLogSchema.index({ property: 1, createdAt: -1 }); 
auditLogSchema.index({ action: 1, createdAt: -1 });   

const AuditLog = mongoose.model('AuditLog', auditLogSchema);

export default AuditLog;

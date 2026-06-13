import mongoose from 'mongoose';

// ==========================================
// NOTIFICATION SCHEMA
// Powers the "Bell Icon" in the dashboard. Keeps track of system alerts, unread status, and delivery channels.
// ==========================================
const notificationSchema = new mongoose.Schema(
  {
    // Which exact staff member or manager is this alert meant for?
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    
    // Optional: Is this alert specific to one hotel branch?
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
    },
    
    // Category of the alert (helps with filtering in the UI)
    type: {
      type: String,
      enum: [
        'booking_confirmed', 'booking_cancelled', 'payment_received',
        'payment_reminder', 'check_in_reminder', 'task_assigned',
        'task_completed', 'task_overdue', 'feedback_received', 'system',
      ],
      required: true,
    },
    
    // The bold header of the alert
    title: {
      type: String,
      required: true,
      trim: true,
    },
    
    // The detailed body text of the alert
    message: {
      type: String,
      required: true,
      trim: true,
    },
    
    // Hidden payload data (e.g. { bookingId: "123" }).
    // This allows the frontend UI to make the notification clickable so it jumps straight to the relevant booking/task.
    data: {
      type: mongoose.Schema.Types.Mixed,
    },
    
    // ==========================================
    // DELIVERY CHANNELS
    // Where was this notification sent?
    // ==========================================
    channels: {
      inApp: { type: Boolean, default: true }, // Show up in the website bell icon?
      email: { type: Boolean, default: false }, // Sent an email?
      sms: { type: Boolean, default: false },   // Sent a text message?
      push: { type: Boolean, default: false },  // Future-proofing: Mobile app push notifications
    },
    
    // Did the user click on it yet?
    read: {
      type: Boolean,
      default: false,
    },
    readAt: {
      type: Date,
    },
    
    // Did the system successfully dispatch it?
    sent: {
      type: Boolean,
      default: false,
    },
    sentAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

// Database Indexes for Speed Optimization
notificationSchema.index({ recipient: 1, read: 1, createdAt: -1 }); // Ultra-fast query for: "Show me my 5 most recent unread alerts"
notificationSchema.index({ property: 1, type: 1 });

const Notification = mongoose.model('Notification', notificationSchema);

export default Notification;

import mongoose from 'mongoose';

// ==========================================
// TASK SCHEMA
// An internal ticketing system for hotel staff (Housekeeping, Maintenance, etc.).
// ==========================================
const taskSchema = new mongoose.Schema(
  {
    // Auto-generated human readable code (e.g., "TSK-240518-0001")
    code: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    
    // Which hotel branch is this task for?
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
      required: true,
      index: true,
    },
    
    // ==========================================
    // CORE TASK DETAILS
    // ==========================================
    title: {
      type: String,
      required: [true, 'Task title is required'],
      trim: true,
      maxlength: 200,
    },
    description: {
      type: String,
      trim: true,
      maxlength: 2000,
    },
    
    // Categorization for filtering and reporting
    type: {
      type: String,
      enum: ['housekeeping', 'maintenance', 'guest_service', 'inspection', 'other'],
      default: 'housekeeping',
    },
    
    // Helps staff know what to do first
    priority: {
      type: String,
      enum: ['low', 'medium', 'high', 'urgent'],
      default: 'medium',
    },
    
    // Workflow state machine
    status: {
      type: String,
      enum: ['open', 'in-progress', 'blocked', 'completed', 'cancelled'],
      default: 'open',
    },
    
    // ==========================================
    // ASSIGNMENTS & CONTEXT
    // ==========================================
    
    // Who is supposed to do the work?
    assignedTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    
    // Who ordered the work to be done?
    assignedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    
    // If the task is physical, where is it? (e.g. "Clean Room 101")
    room: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Room',
    },
    
    // If the task is related to a specific guest stay (e.g. "Deliver extra pillows to Mr. Smith")
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
    },
    
    // ==========================================
    // DEADLINES & TIMETRACKING
    // ==========================================
    dueDate: {
      type: Date,
    },
    dueTime: {
      type: String,
      trim: true,
    },
    completedAt: {
      type: Date,
    },
    completedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    
    // How long should this take vs how long did it actually take? (Used for employee performance reviews)
    estimatedDuration: {
      type: Number, // In minutes
      min: 0,
    },
    actualDuration: {
      type: Number, // In minutes
      min: 0,
    },
    
    // ==========================================
    // DETAILED WORKFLOWS
    // ==========================================
    
    // For breaking a big task ("Deep clean pool") into smaller pieces
    subtasks: [
      {
        title: { type: String, trim: true, required: true },
        completed: { type: Boolean, default: false },
        completedAt: { type: Date },
      },
    ],
    
    // Standardized QA lists (e.g. "1. Change sheets, 2. Empty trash, 3. Restock soap")
    checklist: [
      {
        item: { type: String, trim: true, required: true },
        checked: { type: Boolean, default: false },
        checkedAt: { type: Date },
      },
    ],
    notes: {
      type: String,
      trim: true,
      maxlength: 2000,
    },
    
    // Visual proof. `images` = The mess before. `completedImages` = The clean room after.
    images: [{ type: String }],
    completedImages: [{ type: String }],
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Database Indexes for Speed Optimization
taskSchema.index({ property: 1, status: 1 }); // "Show me all incomplete tasks for this hotel"
taskSchema.index({ assignedTo: 1, status: 1 }); // "Show the logged-in housekeeper their todo list"
taskSchema.index({ property: 1, dueDate: 1 }); // "Show me tasks that are overdue today"
taskSchema.index({ room: 1, status: 1 }); // "Is this room currently being cleaned?"

const Task = mongoose.model('Task', taskSchema);

export default Task;

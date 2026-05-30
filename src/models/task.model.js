import mongoose from 'mongoose';

const taskSchema = new mongoose.Schema(
  {
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
      required: true,
      index: true,
    },
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
    type: {
      type: String,
      enum: ['housekeeping', 'maintenance', 'guest_service', 'inspection', 'other'],
      default: 'housekeeping',
    },
    priority: {
      type: String,
      enum: ['low', 'medium', 'high', 'urgent'],
      default: 'medium',
    },
    status: {
      type: String,
      enum: ['open', 'in-progress', 'blocked', 'completed', 'cancelled'],
      default: 'open',
    },
    assignedTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    assignedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    room: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Room',
    },
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
    },
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
    subtasks: [
      {
        title: { type: String, trim: true, required: true },
        completed: { type: Boolean, default: false },
        completedAt: { type: Date },
      },
    ],
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
    images: [{ type: String }],
    estimatedDuration: {
      type: Number,
      min: 0,
    },
    actualDuration: {
      type: Number,
      min: 0,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

taskSchema.index({ property: 1, status: 1 });
taskSchema.index({ assignedTo: 1, status: 1 });
taskSchema.index({ property: 1, dueDate: 1 });
taskSchema.index({ room: 1, status: 1 });

const Task = mongoose.model('Task', taskSchema);

export default Task;

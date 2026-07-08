import mongoose from 'mongoose';

const roomSchema = new mongoose.Schema(
  {
    code: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
      required: true,
      index: true,
    },
    roomNumber: {
      type: String,
      required: [true, 'Room number is required'],
      trim: true,
    },
    roomType: {
      type: String,
      required: [true, 'Room type is required'],
      enum: ['single', 'double', 'triple', 'suite', 'family', 'deluxe', 'cabana', 'presidential'],
    },
    name: {
      type: String,
      trim: true,
      maxlength: 100,
    },
    capacity: {
      type: Number,
      required: true,
      min: 1,
      max: 20,
    },
    basePrice: {
      type: Number,
      required: true,
      min: 0,
    },
    description: {
      type: String,
      trim: true,
      maxlength: 1000,
    },
    amenities: [{ type: String, trim: true }],
    images: [{ type: String }],
    floor: {
      type: Number,
      default: 0,
    },
    status: {
      type: String,
      enum: ['available', 'booked', 'occupied', 'maintenance', 'out-of-service', 'blocked', 'cleaning'],
      default: 'available',
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    seasonalRates: [
      {
        name: { type: String, trim: true },
        startDate: { type: Date, required: true },
        endDate: { type: Date, required: true },
        price: { type: Number, required: true, min: 0 },
        description: { type: String, trim: true },
      },
    ],
    mealPlans: [
      {
        name: { type: String, trim: true, required: true },
        price: { type: Number, required: true, min: 0 },
        description: { type: String, trim: true },
      },
    ],
    maintenanceHistory: [
      {
        reason: { type: String, trim: true },
        startDate: { type: Date },
        endDate: { type: Date },
        status: { type: String, enum: ['scheduled', 'in-progress', 'completed'], default: 'scheduled' },
        notes: { type: String, trim: true },
      },
    ],
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

roomSchema.index({ property: 1, roomNumber: 1 }, { unique: true });
roomSchema.index({ property: 1, status: 1 });
roomSchema.index({ property: 1, roomType: 1 });

const Room = mongoose.model('Room', roomSchema);

export default Room;

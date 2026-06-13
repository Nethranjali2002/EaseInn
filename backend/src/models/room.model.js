import mongoose from 'mongoose';

// ==========================================
// ROOM SCHEMA
// Represents a specific, physical room inside a hotel (e.g. "Room 204")
// ==========================================
const roomSchema = new mongoose.Schema(
  {
    // Auto-generated human readable code (e.g., "RM-0042")
    code: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    
    // Which hotel branch is this room physically located in?
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
      required: true,
      index: true,
    },
    
    // The actual number painted on the door (e.g., "204")
    roomNumber: {
      type: String,
      required: [true, 'Room number is required'],
      trim: true,
    },
    
    // Categorization for pricing and filtering
    roomType: {
      type: String,
      required: [true, 'Room type is required'],
      enum: ['single', 'double', 'triple', 'suite', 'family', 'deluxe', 'presidential'],
    },
    
    // Optional special name (e.g., "The Honeymoon Suite")
    name: {
      type: String,
      trim: true,
      maxlength: 100,
    },
    
    // Maximum number of guests allowed to sleep here
    capacity: {
      type: Number,
      required: true,
      min: 1,
      max: 20,
    },
    
    // Default nightly price in LKR
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
    
    // E.g. "Ocean View", "Mini-bar", "Balcony"
    amenities: [{ type: String, trim: true }],
    images: [{ type: String }],
    
    // For calculating things like "highest floor rooms"
    floor: {
      type: Number,
      default: 0,
    },
    
    // ==========================================
    // ROOM STATE MACHINE
    // Represents exactly what is happening in this room right now
    // ==========================================
    status: {
      type: String,
      // available: Empty and clean
      // booked: Reserved for the future
      // occupied: Someone is sleeping there right now
      // maintenance: Plumber is fixing the sink
      // blocked: Manager took it off the market
      // cleaning: Housekeeper is inside
      enum: ['available', 'booked', 'occupied', 'maintenance', 'blocked', 'cleaning'],
      default: 'available',
    },
    
    // Has this room been permanently deleted? (Soft delete)
    isActive: {
      type: Boolean,
      default: true,
    },
    
    // ==========================================
    // DYNAMIC PRICING (Surge Pricing)
    // Overrides the basePrice during specific date ranges (e.g. Christmas, New Years)
    // ==========================================
    seasonalRates: [
      {
        name: { type: String, trim: true }, // e.g. "Christmas Eve Special"
        startDate: { type: Date, required: true },
        endDate: { type: Date, required: true },
        price: { type: Number, required: true, min: 0 },
        description: { type: String, trim: true },
      },
    ],
    
    // Add-ons for food
    mealPlans: [
      {
        name: { type: String, trim: true, required: true }, // e.g., "Breakfast Included"
        price: { type: Number, required: true, min: 0 },
        description: { type: String, trim: true },
      },
    ],
    
    // ==========================================
    // MAINTENANCE LOG
    // Keeps a history of when things broke and were fixed
    // ==========================================
    maintenanceHistory: [
      {
        reason: { type: String, trim: true }, // e.g., "Broken AC"
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

// Database Indexes for Speed Optimization
// You cannot have two "Room 101"s in the same hotel branch
roomSchema.index({ property: 1, roomNumber: 1 }, { unique: true });
roomSchema.index({ property: 1, status: 1 }); // Quickly find all "cleaning" rooms in a specific hotel
roomSchema.index({ property: 1, roomType: 1 }); // Quickly find all "suites" in a specific hotel

const Room = mongoose.model('Room', roomSchema);

export default Room;

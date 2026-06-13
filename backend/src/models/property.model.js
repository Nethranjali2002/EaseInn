import mongoose from 'mongoose';

// ==========================================
// PROPERTY SCHEMA
// Represents a physical hotel building/branch. Allows the system to support multiple hotels (multi-tenant architecture).
// ==========================================
const propertySchema = new mongoose.Schema(
  {
    // Auto-generated human readable code (e.g., "PRP-0001")
    code: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    
    // Who owns/manages this specific hotel branch?
    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    
    // The public name of the hotel (e.g., "EaseInn Downtown")
    name: {
      type: String,
      required: [true, 'Property name is required'],
      trim: true,
      maxlength: 200,
    },
    description: {
      type: String,
      trim: true,
      maxlength: 2000,
    },
    
    // ==========================================
    // LOCATION DETAILS
    // ==========================================
    address: {
      street: { type: String, trim: true },
      city: { type: String, trim: true, required: true },
      state: { type: String, trim: true },
      country: { type: String, trim: true, default: 'Sri Lanka' },
      zipCode: { type: String, trim: true },
    },
    contact: {
      phone: { type: String, trim: true },
      email: { type: String, trim: true, lowercase: true },
      website: { type: String, trim: true },
    },
    
    // E.g. "Pool", "Gym", "Free WiFi"
    amenities: [{ type: String, trim: true }],
    
    // Links to images hosted on ImgBB
    images: [{ type: String }],
    logo: { type: String, default: '' },
    coverImage: { type: String, default: '' },
    
    // Is this hotel currently open for business? (Soft delete)
    isActive: {
      type: Boolean,
      default: true,
    },
    
    // A cached count of how many rooms this hotel has, to prevent having to count them all every time
    totalRooms: {
      type: Number,
      default: 0,
    },
    
    // Local government tax percentage (e.g., 15 for 15% VAT)
    taxRate: {
      type: Number,
      default: 0,
      min: 0,
      max: 100,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true }, // Allow virtual fields to be included when converting to JSON
    toObject: { virtuals: true },
  }
);

// ==========================================
// VIRTUAL POPULATION
// A clever MongoDB trick. We don't save an array of Room IDs directly in the Property model.
// Instead, we tell Mongoose: "If I ask for 'rooms', go find all Room documents where property == this property's _id"
// ==========================================
propertySchema.virtual('rooms', {
  ref: 'Room',
  localField: '_id',
  foreignField: 'property',
});

// Database Indexes for Speed Optimization
propertySchema.index({ owner: 1, isActive: 1 }); // Quickly load all active hotels owned by the currently logged-in admin

const Property = mongoose.model('Property', propertySchema);

export default Property;

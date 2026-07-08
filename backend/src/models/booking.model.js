import mongoose from 'mongoose';


const bookingSchema = new mongoose.Schema(
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
    
    room: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Room',
      required: true,
    },
    
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    
   
    guest: {
      name: { type: String, required: true, trim: true },
      email: { type: String, trim: true, lowercase: true },
      phone: { type: String, trim: true },
      idType: { type: String, enum: ['nic', 'passport', 'driving_license', 'other'] }, 
      idNumber: { type: String, trim: true },
      idImage: { type: String }, 
      address: { type: String, trim: true },
      nationality: { type: String, trim: true },
    },
    
    
    checkIn: {
      type: Date,
      required: true,
    },
    checkOut: {
      type: Date,
      required: true,
    },
    numberOfGuests: {
      type: Number,
      required: true,
      min: 1, 
    },
    adults: { type: Number, default: 1, min: 0 },
    children: { type: Number, default: 0, min: 0 },
    
    roomType: {
      type: String,
      required: true,
    },
    

    mealPlan: {
      type: String,
      trim: true,
    },
    
    
    pricing: {
      basePrice: { type: Number, required: true }, 
      nights: { type: Number, required: true }, 
      roomTotal: { type: Number, required: true }, 
      mealPlanTotal: { type: Number, default: 0 },
      
      addons: [
        {
          name: { type: String, trim: true },
          price: { type: Number, min: 0 },
        },
      ],
      discount: { type: Number, default: 0 }, 
      tax: { type: Number, default: 0 }, 
      totalAmount: { type: Number, required: true }, 
    },
    
    
    paymentStatus: {
      type: String,
      enum: ['pending', 'partial', 'paid', 'refunded', 'cancelled'],
      default: 'pending',
    },
    
    amountPaid: {
      type: Number,
      default: 0,
    },
    
    bookingStatus: {
      type: String,
      
      enum: ['draft', 'pending-payment', 'confirmed', 'checked-in', 'checked-out', 'completed', 'cancelled'],
      default: 'pending-payment',
    },
    
    cancellationReason: {
      type: String,
      trim: true,
    },
    cancelledAt: {
      type: Date,
    },
    specialRequests: { 
      type: String,
      trim: true,
      maxlength: 500,
    },
    notes: { 
      type: String,
      trim: true,
      maxlength: 1000,
    },
    source: { 
      type: String,
      enum: ['direct', 'phone', 'website', 'walk-in', 'other'],
      default: 'direct',
    },
    
    reviewToken: { 
      type: String,
      unique: true,
      sparse: true,
    },
    reviewTokenExpiresAt: { 
      type: Date,
    },
    reviewSubmitted: { 
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

bookingSchema.index({ property: 1, checkIn: 1, checkOut: 1 });
bookingSchema.index({ property: 1, bookingStatus: 1 });
bookingSchema.index({ room: 1, checkIn: 1, checkOut: 1 });
bookingSchema.index({ createdBy: 1 });

const Booking = mongoose.model('Booking', bookingSchema);

export default Booking;

import mongoose from 'mongoose';

// ==========================================
// BOOKING SCHEMA
// The absolute core of the hotel system. Ties together Guests, Rooms, and Payments into a single event.
// ==========================================
const bookingSchema = new mongoose.Schema(
  {
    // The human-readable confirmation code (e.g. "BKG-240518-0001"). Generated automatically.
    code: {
      type: String,
      unique: true,
      sparse: true, // Sparse allows multiple bookings to exist without a code temporarily during the creation process
      index: true,
    },
    
    // Which specific hotel branch this reservation is for
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
      required: true,
      index: true,
    },
    
    // Which exact physical room they will sleep in
    room: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Room',
      required: true,
    },
    
    // Which staff member typed this into the computer (for accountability)
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    
    // ==========================================
    // GUEST INFORMATION (Embedded Document)
    // We embed this directly instead of using a separate "Guest" table because guest details often change per booking
    // ==========================================
    guest: {
      name: { type: String, required: true, trim: true },
      email: { type: String, trim: true, lowercase: true },
      phone: { type: String, trim: true },
      idType: { type: String, enum: ['nic', 'passport', 'driving_license', 'other'] }, // Required for legal compliance in many countries
      idNumber: { type: String, trim: true },
      idImage: { type: String }, // URL to an uploaded photo of their ID card
      address: { type: String, trim: true },
      nationality: { type: String, trim: true },
    },
    
    // ==========================================
    // STAY DETAILS
    // ==========================================
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
      min: 1, // You can't book a room for 0 people
    },
    adults: { type: Number, default: 1, min: 0 },
    children: { type: Number, default: 0, min: 0 },
    
    // Snapshot of the room category at the time of booking (e.g., "Deluxe Suite"). 
    // Saved here so if the manager renames the category next year, this historical record isn't affected.
    roomType: {
      type: String,
      required: true,
    },
    
    // Breakfast included, Full Board, etc.
    mealPlan: {
      type: String,
      trim: true,
    },
    
    // ==========================================
    // FINANCIAL CALCULATIONS
    // ==========================================
    pricing: {
      basePrice: { type: Number, required: true }, // The nightly rate
      nights: { type: Number, required: true }, // Total nights
      roomTotal: { type: Number, required: true }, // basePrice * nights
      mealPlanTotal: { type: Number, default: 0 }, // Cost of food
      
      // Extras they bought (e.g. Airport Transfer, Champagne)
      addons: [
        {
          name: { type: String, trim: true },
          price: { type: Number, min: 0 },
        },
      ],
      discount: { type: Number, default: 0 }, // Amount to subtract
      tax: { type: Number, default: 0 }, // Local government taxes
      totalAmount: { type: Number, required: true }, // The final, bottom-line number they must pay
    },
    
    // ==========================================
    // STATE MACHINES (Crucial for Business Logic)
    // ==========================================
    
    // How much money have they actually handed us?
    paymentStatus: {
      type: String,
      enum: ['pending', 'partial', 'paid', 'refunded', 'cancelled'],
      default: 'pending',
    },
    
    // A running total of all successful Payment records attached to this booking
    amountPaid: {
      type: Number,
      default: 0,
    },
    
    // Where is the guest physically located right now?
    bookingStatus: {
      type: String,
      // pending-payment: Waiting for Stripe to confirm.
      // confirmed: Paid and waiting for arrival.
      // checked-in: Physically inside the hotel.
      // checked-out: They left, but the room needs cleaning.
      // completed: Everything is done and archived.
      enum: ['draft', 'pending-payment', 'confirmed', 'checked-in', 'checked-out', 'completed', 'cancelled'],
      default: 'pending-payment',
    },
    
    // ==========================================
    // METADATA
    // ==========================================
    cancellationReason: {
      type: String,
      trim: true,
    },
    cancelledAt: {
      type: Date,
    },
    specialRequests: { // E.g., "Allergic to feathers, please provide synthetic pillows"
      type: String,
      trim: true,
      maxlength: 500,
    },
    notes: { // Private notes only staff can see
      type: String,
      trim: true,
      maxlength: 1000,
    },
    source: { // Where did this booking come from? (Helps with marketing analytics)
      type: String,
      enum: ['direct', 'phone', 'website', 'walk-in', 'other'],
      default: 'direct',
    },
    
    // ==========================================
    // POST-STAY REVIEW SYSTEM
    // ==========================================
    reviewToken: { // A secret password mailed to the guest so ONLY they can leave a review
      type: String,
      unique: true,
      sparse: true,
    },
    reviewTokenExpiresAt: { // Usually expires 30 days after check-out
      type: Date,
    },
    reviewSubmitted: { // Prevents them from leaving multiple reviews for the same stay
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

// Database Indexes for Speed Optimization
// Frequently used to find out "Is Room X available between Date Y and Date Z?"
bookingSchema.index({ property: 1, checkIn: 1, checkOut: 1 });
bookingSchema.index({ property: 1, bookingStatus: 1 });
bookingSchema.index({ room: 1, checkIn: 1, checkOut: 1 });
bookingSchema.index({ createdBy: 1 });

const Booking = mongoose.model('Booking', bookingSchema);

export default Booking;

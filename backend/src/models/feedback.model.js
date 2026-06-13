import mongoose from 'mongoose';

// ==========================================
// FEEDBACK SCHEMA
// Stores the "Post-Stay Reviews" submitted by guests after they check out.
// Used to calculate hotel ratings and track customer satisfaction.
// ==========================================
const feedbackSchema = new mongoose.Schema(
  {
    // Which hotel branch is this review for?
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
      required: true,
      index: true,
    },
    
    // The specific reservation this review is tied to (ensures only real guests can leave reviews)
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      required: true,
    },
    
    // Guest contact info
    guestName: {
      type: String,
      required: true,
      trim: true,
    },
    guestEmail: {
      type: String,
      trim: true,
      lowercase: true,
    },
    
    // ==========================================
    // REVIEW CONTENT
    // ==========================================
    
    // The big overall star rating (1 to 5)
    rating: {
      type: Number,
      required: true,
      min: 1,
      max: 5,
    },
    
    // A short summary (e.g. "Loved the breakfast!")
    title: {
      type: String,
      trim: true,
      maxlength: 200,
    },
    
    // The long-form written text
    comment: {
      type: String,
      trim: true,
      maxlength: 2000,
    },
    
    // Breakdown of specific areas (like TripAdvisor)
    categories: {
      cleanliness: { type: Number, min: 1, max: 5 },
      comfort: { type: Number, min: 1, max: 5 },
      location: { type: Number, min: 1, max: 5 },
      service: { type: Number, min: 1, max: 5 },
      value: { type: Number, min: 1, max: 5 },
    },
    
    // ==========================================
    // MANAGEMENT RESPONSE
    // Allows the hotel manager to publicly reply to the review
    // ==========================================
    response: {
      text: { type: String, trim: true, maxlength: 1000 },
      respondedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, // Which manager replied?
      respondedAt: { type: Date }, // When did they reply?
    },
    
    // Simple Yes/No metric for Net Promoter Score calculation
    recommendation: {
      type: String,
      enum: ['Yes', 'No'],
      default: 'Yes',
    },
    
    // ==========================================
    // INTERNAL WORKFLOW
    // Helps managers track which bad reviews still need an apology or refund
    // ==========================================
    status: {
      type: String,
      enum: ['New', 'Reviewed', 'Resolved'],
      default: 'New',
    },
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    resolutionDate: {
      type: Date,
    },
    
    // Can this review be shown on the public website, or is it private/hidden?
    isPublic: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

// Database Indexes for Speed Optimization
feedbackSchema.index({ property: 1, rating: 1 }); // Quickly find all 5-star or 1-star reviews for a specific hotel
feedbackSchema.index({ booking: 1 }); // Quickly check if a specific booking already has a review attached to it

const Feedback = mongoose.model('Feedback', feedbackSchema);

export default Feedback;

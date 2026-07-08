import mongoose from 'mongoose';

// FEEDBACK SCHEMA

const feedbackSchema = new mongoose.Schema(
  {
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
      required: true,
      index: true,
    },
    
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      required: true,
    },
    
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
    
    
    // REVIEW CONTENT
    
    rating: {
      type: Number,
      required: true,
      min: 1,
      max: 5,
    },
    
    title: {
      type: String,
      trim: true,
      maxlength: 200,
    },
    
    comment: {
      type: String,
      trim: true,
      maxlength: 2000,
    },
    
    categories: {
      cleanliness: { type: Number, min: 1, max: 5 },
      comfort: { type: Number, min: 1, max: 5 },
      location: { type: Number, min: 1, max: 5 },
      service: { type: Number, min: 1, max: 5 },
      value: { type: Number, min: 1, max: 5 },
    },
    
    response: {
      text: { type: String, trim: true, maxlength: 1000 },
      respondedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' }, 
      respondedAt: { type: Date }, 
    },
    
    // Simple Yes/No metric for Net Promoter Score calculation
    recommendation: {
      type: String,
      enum: ['Yes', 'No'],
      default: 'Yes',
    },
    
    // Helps managers track which bad reviews still need an apology or refund
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
    
    isPublic: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

feedbackSchema.index({ property: 1, rating: 1 });
feedbackSchema.index({ booking: 1 }); 

const Feedback = mongoose.model('Feedback', feedbackSchema);

export default Feedback;

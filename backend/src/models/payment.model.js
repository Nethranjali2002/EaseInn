import mongoose from 'mongoose';

const paymentSchema = new mongoose.Schema(
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
    
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      required: true,
      index: true,
    },
    
    // TRANSACTION DETAILS
    amount: {
      type: Number,
      required: true,
      min: 0, 
    },
    currency: {
      type: String,
      default: 'LKR',
      uppercase: true,
    },
    
    method: {
      type: String,
      enum: ['cash', 'card', 'bank_transfer', 'online', 'other'],
      default: 'online',
    },
    
    type: {
      type: String,
      enum: ['advance', 'partial', 'full', 'refund'],
      required: true,
    },
    
    status: {
      type: String,
      enum: ['pending', 'processing', 'completed', 'failed', 'refunded'],
      default: 'pending',
    },
    
    // ONLINE PAYMENT GATEWAY TRACKING 
    gateway: {
      name: { type: String, trim: true },
      transactionId: { type: String, trim: true }, 
      reference: { type: String, trim: true }, 
      response: { type: mongoose.Schema.Types.Mixed }, 
    },
    
    paidAt: {
      type: Date,
    },
    
    // If they paid in cash at the front desk, which receptionist pressed the button?
    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    
    notes: {
      type: String,
      trim: true,
      maxlength: 500,
    },
    
    invoiceNumber: {
      type: String,
      unique: true,
      sparse: true,
    },
    
    // REFUND METADATA
    refundReason: {
      type: String,
      trim: true,
    },
    refundedAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

paymentSchema.index({ booking: 1, status: 1 }); 
paymentSchema.index({ property: 1, paidAt: 1 }); 
paymentSchema.index({ 'gateway.transactionId': 1 }); 

const Payment = mongoose.model('Payment', paymentSchema);

export default Payment;

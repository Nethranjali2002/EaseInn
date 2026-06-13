import mongoose from 'mongoose';

// ==========================================
// PAYMENT SCHEMA
// A financial ledger. Represents a single transaction (money changing hands) rather than a whole booking.
// One Booking might have multiple Payments (e.g., $100 deposit, then $400 final payment).
// ==========================================
const paymentSchema = new mongoose.Schema(
  {
    // Auto-generated human readable code (e.g., "INV-240518-0001")
    code: {
      type: String,
      unique: true,
      sparse: true,
      index: true,
    },
    
    // Which hotel is collecting this money?
    property: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Property',
      required: true,
      index: true,
    },
    
    // Which reservation is this paying for?
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Booking',
      required: true,
      index: true,
    },
    
    // ==========================================
    // TRANSACTION DETAILS
    // ==========================================
    amount: {
      type: Number,
      required: true,
      min: 0, // Cannot have a negative payment. Refunds are handled via 'type: refund'
    },
    currency: {
      type: String,
      default: 'LKR',
      uppercase: true,
    },
    
    // How did they pay?
    method: {
      type: String,
      enum: ['cash', 'card', 'bank_transfer', 'online', 'other'],
      default: 'online',
    },
    
    // Is this a deposit (advance), a partial payment, paying off the final balance (full), or giving money back (refund)?
    type: {
      type: String,
      enum: ['advance', 'partial', 'full', 'refund'],
      required: true,
    },
    
    // State machine for the transaction itself
    status: {
      type: String,
      enum: ['pending', 'processing', 'completed', 'failed', 'refunded'],
      default: 'pending',
    },
    
    // ==========================================
    // ONLINE PAYMENT GATEWAY TRACKING (e.g. Stripe)
    // ==========================================
    gateway: {
      name: { type: String, trim: true }, // e.g., "Stripe"
      transactionId: { type: String, trim: true }, // Stripe's ID for tracking it on their end (e.g., "pi_3M...")
      reference: { type: String, trim: true }, // A unique checkout session ID
      response: { type: mongoose.Schema.Types.Mixed }, // Raw JSON receipt dumped straight from Stripe for auditing
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
    
    // The official document number handed to the guest
    invoiceNumber: {
      type: String,
      unique: true,
      sparse: true,
    },
    
    // ==========================================
    // REFUND METADATA
    // ==========================================
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

// Database Indexes for Speed Optimization
paymentSchema.index({ booking: 1, status: 1 }); // Quickly sum up all "completed" payments for a specific booking to find the remaining balance
paymentSchema.index({ property: 1, paidAt: 1 }); // Quickly generate the "Daily Revenue Report" for a specific hotel
paymentSchema.index({ 'gateway.transactionId': 1 }); // Vital for Stripe Webhooks to instantly find the correct database row when a payment succeeds in the background

const Payment = mongoose.model('Payment', paymentSchema);

export default Payment;

import Joi from 'joi';

export const createPropertySchema = Joi.object({
  name: Joi.string().trim().max(200).required(),
  description: Joi.string().trim().max(2000).optional(),
  address: Joi.object({
    street: Joi.string().trim().optional(),
    city: Joi.string().trim().required(),
    state: Joi.string().trim().optional(),
    country: Joi.string().trim().default('Sri Lanka'),
    zipCode: Joi.string().trim().optional(),
  }).required(),
  contact: Joi.object({
    phone: Joi.string().trim().optional(),
    email: Joi.string().email().trim().lowercase().optional(),
    website: Joi.string().uri().trim().optional(),
  }).optional(),
  amenities: Joi.array().items(Joi.string().trim()).optional(),
  images: Joi.array().items(Joi.string()).optional(),
});

export const updatePropertySchema = Joi.object({
  name: Joi.string().trim().max(200).optional(),
  description: Joi.string().trim().max(2000).optional(),
  address: Joi.object({
    street: Joi.string().trim().optional(),
    city: Joi.string().trim().required(),
    state: Joi.string().trim().optional(),
    country: Joi.string().trim().optional(),
    zipCode: Joi.string().trim().optional(),
  }).optional(),
  contact: Joi.object({
    phone: Joi.string().trim().optional(),
    email: Joi.string().email().trim().lowercase().optional(),
    website: Joi.string().uri().trim().optional(),
  }).optional(),
  amenities: Joi.array().items(Joi.string().trim()).optional(),
  images: Joi.array().items(Joi.string()).optional(),
  isActive: Joi.boolean().optional(),
}).min(1);

export const createRoomSchema = Joi.object({
  roomNumber: Joi.string().trim().required(),
  roomType: Joi.string().valid('single', 'double', 'triple', 'suite', 'family', 'deluxe', 'presidential').required(),
  name: Joi.string().trim().max(100).optional(),
  capacity: Joi.number().integer().min(1).max(20).required(),
  basePrice: Joi.number().min(0).required(),
  description: Joi.string().trim().max(1000).optional(),
  amenities: Joi.array().items(Joi.string().trim()).optional(),
  images: Joi.array().items(Joi.string()).optional(),
  floor: Joi.number().integer().optional(),
  seasonalRates: Joi.array().items(Joi.object({
    name: Joi.string().trim().optional(),
    startDate: Joi.date().required(),
    endDate: Joi.date().required(),
    price: Joi.number().min(0).required(),
    description: Joi.string().trim().optional(),
  })).optional(),
  mealPlans: Joi.array().items(Joi.object({
    name: Joi.string().trim().required(),
    price: Joi.number().min(0).required(),
    description: Joi.string().trim().optional(),
  })).optional(),
});

export const updateRoomSchema = Joi.object({
  roomNumber: Joi.string().trim().optional(),
  roomType: Joi.string().valid('single', 'double', 'triple', 'suite', 'family', 'deluxe', 'presidential').optional(),
  name: Joi.string().trim().max(100).optional(),
  capacity: Joi.number().integer().min(1).max(20).optional(),
  basePrice: Joi.number().min(0).optional(),
  description: Joi.string().trim().max(1000).optional(),
  amenities: Joi.array().items(Joi.string().trim()).optional(),
  images: Joi.array().items(Joi.string()).optional(),
  floor: Joi.number().integer().optional(),
  status: Joi.string().valid('available', 'booked', 'occupied', 'maintenance', 'blocked', 'cleaning').optional(),
  isActive: Joi.boolean().optional(),
  seasonalRates: Joi.array().items(Joi.object({
    name: Joi.string().trim().optional(),
    startDate: Joi.date().required(),
    endDate: Joi.date().required(),
    price: Joi.number().min(0).required(),
    description: Joi.string().trim().optional(),
  })).optional(),
  mealPlans: Joi.array().items(Joi.object({
    name: Joi.string().trim().required(),
    price: Joi.number().min(0).required(),
    description: Joi.string().trim().optional(),
  })).optional(),
}).min(1);

export const createBookingSchema = Joi.object({
  property: Joi.string().hex().length(24).required(),
  room: Joi.string().hex().length(24).required(),
  guest: Joi.object({
    name: Joi.string().trim().required(),
    email: Joi.string().email().trim().lowercase().optional(),
    phone: Joi.string().trim().optional(),
    idType: Joi.string().valid('nic', 'passport', 'driving_license', 'other').optional(),
    idNumber: Joi.string().trim().optional(),
    idImage: Joi.string().optional(),
    address: Joi.string().trim().optional(),
    nationality: Joi.string().trim().optional(),
  }).required(),
  checkIn: Joi.date().required(),
  checkOut: Joi.date().greater(Joi.ref('checkIn')).required(),
  numberOfGuests: Joi.number().integer().min(1).required(),
  adults: Joi.number().integer().min(0).optional(),
  children: Joi.number().integer().min(0).optional(),
  roomType: Joi.string().required(),
  mealPlan: Joi.string().trim().optional(),
  addons: Joi.array().items(Joi.object({
    name: Joi.string().trim().required(),
    price: Joi.number().min(0).required(),
  })).optional(),
  discount: Joi.number().min(0).optional(),
  specialRequests: Joi.string().trim().max(500).optional(),
  notes: Joi.string().trim().max(1000).optional(),
  source: Joi.string().valid('direct', 'phone', 'website', 'walk-in', 'other').optional(),
});

export const updateBookingSchema = Joi.object({
  checkIn: Joi.date().optional(),
  checkOut: Joi.date().greater(Joi.ref('checkIn')).optional(),
  numberOfGuests: Joi.number().integer().min(1).optional(),
  adults: Joi.number().integer().min(0).optional(),
  children: Joi.number().integer().min(0).optional(),
  guest: Joi.object({
    name: Joi.string().trim().optional(),
    email: Joi.string().email().trim().lowercase().optional(),
    phone: Joi.string().trim().optional(),
    idType: Joi.string().valid('nic', 'passport', 'driving_license', 'other').optional(),
    idNumber: Joi.string().trim().optional(),
    idImage: Joi.string().optional(),
    address: Joi.string().trim().optional(),
    nationality: Joi.string().trim().optional(),
  }).optional(),
  specialRequests: Joi.string().trim().max(500).optional(),
  notes: Joi.string().trim().max(1000).optional(),
  bookingStatus: Joi.string().valid('pending', 'confirmed', 'checked-in', 'checked-out', 'cancelled', 'no-show').optional(),
  cancellationReason: Joi.string().trim().max(500).optional(),
}).min(1);

export const createTaskSchema = Joi.object({
  property: Joi.string().hex().length(24).required(),
  title: Joi.string().trim().max(200).required(),
  description: Joi.string().trim().max(2000).optional(),
  type: Joi.string().valid('housekeeping', 'maintenance', 'guest_service', 'inspection', 'other').optional(),
  priority: Joi.string().valid('low', 'medium', 'high', 'urgent').optional(),
  assignedTo: Joi.string().hex().length(24).optional(),
  room: Joi.string().hex().length(24).optional(),
  booking: Joi.string().hex().length(24).optional(),
  dueDate: Joi.date().optional(),
  dueTime: Joi.string().trim().optional(),
  subtasks: Joi.array().items(Joi.object({
    title: Joi.string().trim().required(),
  })).optional(),
  checklist: Joi.array().items(Joi.object({
    item: Joi.string().trim().required(),
  })).optional(),
  notes: Joi.string().trim().max(2000).optional(),
  estimatedDuration: Joi.number().min(0).optional(),
});

export const updateTaskSchema = Joi.object({
  title: Joi.string().trim().max(200).optional(),
  description: Joi.string().trim().max(2000).optional(),
  type: Joi.string().valid('housekeeping', 'maintenance', 'guest_service', 'inspection', 'other').optional(),
  priority: Joi.string().valid('low', 'medium', 'high', 'urgent').optional(),
  status: Joi.string().valid('open', 'in-progress', 'blocked', 'completed', 'cancelled').optional(),
  assignedTo: Joi.string().hex().length(24).optional(),
  dueDate: Joi.date().optional(),
  dueTime: Joi.string().trim().optional(),
  notes: Joi.string().trim().max(2000).optional(),
  images: Joi.array().items(Joi.string()).optional(),
  estimatedDuration: Joi.number().min(0).optional(),
}).min(1);

export const createPaymentSchema = Joi.object({
  booking: Joi.string().hex().length(24).required(),
  amount: Joi.number().min(0).required(),
  currency: Joi.string().uppercase().length(3).optional(),
  method: Joi.string().valid('cash', 'card', 'bank_transfer', 'online', 'other').optional(),
  type: Joi.string().valid('advance', 'partial', 'full', 'refund').required(),
  gateway: Joi.object({
    name: Joi.string().trim().optional(),
    transactionId: Joi.string().trim().optional(),
    reference: Joi.string().trim().optional(),
  }).optional(),
  notes: Joi.string().trim().max(500).optional(),
});

export const respondFeedbackSchema = Joi.object({
  text: Joi.string().trim().max(1000).required(),
}).min(1);

export const submitReviewSchema = Joi.object({
  token: Joi.string().hex().length(64).required(),
  rating: Joi.number().integer().min(1).max(5).required(),
  title: Joi.string().trim().max(200).optional(),
  comment: Joi.string().trim().max(2000).optional(),
  categories: Joi.object({
    cleanliness: Joi.number().integer().min(1).max(5).optional(),
    comfort: Joi.number().integer().min(1).max(5).optional(),
    location: Joi.number().integer().min(1).max(5).optional(),
    service: Joi.number().integer().min(1).max(5).optional(),
    value: Joi.number().integer().min(1).max(5).optional(),
  }).optional(),
});

export const guestBookingSchema = Joi.object({
  property: Joi.string().hex().length(24).required(),
  room: Joi.string().hex().length(24).required(),
  guest: Joi.object({
    name: Joi.string().trim().required(),
    email: Joi.string().email().trim().lowercase().required(),
    phone: Joi.string().trim().optional(),
    idType: Joi.string().valid('nic', 'passport', 'driving_license', 'other').optional(),
    idNumber: Joi.string().trim().optional(),
    address: Joi.string().trim().optional(),
    nationality: Joi.string().trim().optional(),
  }).required(),
  checkIn: Joi.date().required(),
  checkOut: Joi.date().greater(Joi.ref('checkIn')).required(),
  numberOfGuests: Joi.number().integer().min(1).required(),
  adults: Joi.number().integer().min(0).optional(),
  children: Joi.number().integer().min(0).optional(),
  roomType: Joi.string().required(),
  mealPlan: Joi.string().trim().optional(),
  addons: Joi.array().items(Joi.object({
    name: Joi.string().trim().required(),
    price: Joi.number().min(0).required(),
  })).optional(),
  specialRequests: Joi.string().trim().max(500).optional(),
});


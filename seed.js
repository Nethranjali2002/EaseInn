import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import 'dotenv/config';

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/easeinn';

async function seed() {
  await mongoose.connect(MONGO_URI);
  console.log('Connected to MongoDB');

  const db = mongoose.connection.db;
  await db.dropDatabase();
  console.log('Database dropped');

  const passwordHash = await bcrypt.hash('password123', 12);

  const adminId = new mongoose.Types.ObjectId('000000000000000000000001');
  const manager1Id = new mongoose.Types.ObjectId('000000000000000000000011');
  const manager2Id = new mongoose.Types.ObjectId('000000000000000000000012');
  const staff1Id = new mongoose.Types.ObjectId('111111111111111111111111');
  const staff2Id = new mongoose.Types.ObjectId('222222222222222222222222');
  const staff3Id = new mongoose.Types.ObjectId('333333333333333333333333');

  // ========== USERS ==========
  const users = [
    { _id: adminId, name: 'Kamal Perera', email: 'kamal@easeinn.com', password: passwordHash, role: 'admin', createdAt: new Date(), updatedAt: new Date() },
    { _id: manager1Id, name: 'Nadeesha Silva', email: 'nadeesha@easeinn.com', password: passwordHash, role: 'manager', createdAt: new Date(), updatedAt: new Date() },
    { _id: manager2Id, name: 'Ashan Fernando', email: 'ashan@easeinn.com', password: passwordHash, role: 'manager', createdAt: new Date(), updatedAt: new Date() },
    { _id: staff1Id, name: 'Dilshan Rajapaksa', email: 'dilshan@easeinn.com', password: passwordHash, role: 'staff', createdAt: new Date(), updatedAt: new Date() },
    { _id: staff2Id, name: 'Kavindu Bandara', email: 'kavindu@easeinn.com', password: passwordHash, role: 'staff', createdAt: new Date(), updatedAt: new Date() },
    { _id: staff3Id, name: 'Tharaka Mendis', email: 'tharaka@easeinn.com', password: passwordHash, role: 'staff', createdAt: new Date(), updatedAt: new Date() },
  ];

  await db.collection('users').insertMany(users);
  console.log('Users created: 6');

  // ========== PROPERTIES ==========
  const properties = [
    {
      name: 'Seaside Resort & Spa',
      description: 'Luxury beachfront resort with stunning ocean views, world-class spa, and fine dining. Located in the heart of Galle.',
      owner: adminId,
      address: { street: '123 Beach Road', city: 'Galle', state: 'Southern', country: 'Sri Lanka', zipCode: '80000' },
      contact: { phone: '+94 91 223 4567', email: 'info@seaside.lk', website: 'https://seaside.lk' },
      amenities: ['Swimming Pool', 'Spa', 'Restaurant', 'Free WiFi', 'Beach Access', 'Parking', 'Gym', 'Room Service', 'Airport Transfer'],
      totalRooms: 5, isActive: true, createdAt: new Date(), updatedAt: new Date(),
    },
    {
      name: 'Mountain View Inn',
      description: 'A cozy mountain retreat surrounded by lush tea plantations in the cool hills of Nuwara Eliya.',
      owner: adminId,
      address: { street: '45 Hill Station Road', city: 'Nuwara Eliya', state: 'Central', country: 'Sri Lanka', zipCode: '22200' },
      contact: { phone: '+94 52 222 1234', email: 'info@mountainview.lk' },
      amenities: ['Garden', 'Fireplace', 'Free WiFi', 'Hiking Tours', 'Restaurant', 'Library', 'BBQ Area'],
      totalRooms: 4, isActive: true, createdAt: new Date(), updatedAt: new Date(),
    },
    {
      name: 'Lagoon Eco Lodge',
      description: 'Eco-friendly lodge on the banks of a scenic lagoon. Perfect for nature lovers and bird watchers.',
      owner: adminId,
      address: { street: '12 Lagoon Road', city: 'Kitulgala', state: 'Western', country: 'Sri Lanka', zipCode: '10720' },
      contact: { phone: '+94 36 225 6789', email: 'info@lagooneco.lk' },
      amenities: ['Kayaking', 'Bird Watching', 'Campfire', 'Free WiFi', 'Organic Restaurant', 'Nature Trails'],
      totalRooms: 3, isActive: true, createdAt: new Date(), updatedAt: new Date(),
    },
    {
      name: 'Ella Jungle Canopy',
      description: 'Luxe tents and canopy cabins suspended above the rainforest canopy. Experience wilderness in style.',
      owner: adminId,
      address: { street: 'Wellawaya Road', city: 'Ella', state: 'Uva', country: 'Sri Lanka', zipCode: '90090' },
      contact: { phone: '+94 57 222 9876', email: 'canopy@ella.lk' },
      amenities: ['Hiking Trails', 'Infinity Pool', 'Free WiFi', 'Yoga Deck', 'Spa', 'Restaurant'],
      totalRooms: 3, isActive: true, createdAt: new Date(), updatedAt: new Date(),
    },
  ];
  const propResult = await db.collection('properties').insertMany(properties);
  const propIds = Object.values(propResult.insertedIds);
  console.log('Properties created: 4');

  // ========== ROOMS ==========
  const rooms = [
    // Seaside Resort
    { property: propIds[0], roomNumber: '101', roomType: 'single', name: 'Ocean Breeze Single', capacity: 1, basePrice: 8500, floor: 1, status: 'available', amenities: ['AC', 'TV', 'Mini Bar', 'Sea View'], isActive: true, seasonalRates: [], mealPlans: [{ name: 'Bed & Breakfast', price: 2000 }, { name: 'Half Board', price: 4500 }], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], roomNumber: '102', roomType: 'double', name: 'Sunset Double', capacity: 2, basePrice: 12000, floor: 1, status: 'booked', amenities: ['AC', 'TV', 'Mini Bar', 'Balcony'], isActive: true, seasonalRates: [], mealPlans: [{ name: 'Bed & Breakfast', price: 2000 }, { name: 'Half Board', price: 4500 }], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], roomNumber: '201', roomType: 'suite', name: 'Coral Suite', capacity: 2, basePrice: 22000, floor: 2, status: 'available', amenities: ['AC', 'TV', 'Mini Bar', 'Jacuzzi', 'Ocean View', 'Living Area'], isActive: true, seasonalRates: [], mealPlans: [{ name: 'Full Board', price: 7000 }], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], roomNumber: '202', roomType: 'family', name: 'Palm Family Room', capacity: 4, basePrice: 18000, floor: 2, status: 'available', amenities: ['AC', 'TV', 'Mini Bar', 'Extra Beds', 'Kids Area'], isActive: true, seasonalRates: [], mealPlans: [{ name: 'Full Board', price: 7000 }], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], roomNumber: '301', roomType: 'presidential', name: 'Presidential Suite', capacity: 3, basePrice: 45000, floor: 3, status: 'available', amenities: ['AC', 'TV', 'Mini Bar', 'Jacuzzi', 'Panoramic View', 'Private Pool', 'Butler Service'], isActive: true, seasonalRates: [], mealPlans: [{ name: 'All Inclusive', price: 12000 }], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    // Mountain View
    { property: propIds[1], roomNumber: 'A1', roomType: 'single', name: 'Garden View Single', capacity: 1, basePrice: 5500, floor: 1, status: 'available', amenities: ['Heater', 'TV', 'Garden View'], isActive: true, seasonalRates: [], mealPlans: [], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[1], roomNumber: 'A2', roomType: 'double', name: 'Tea Plantation Double', capacity: 2, basePrice: 8000, floor: 1, status: 'booked', amenities: ['Heater', 'TV', 'Fireplace', 'Tea View'], isActive: true, seasonalRates: [], mealPlans: [], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[1], roomNumber: 'B1', roomType: 'deluxe', name: 'Mountain Deluxe', capacity: 2, basePrice: 15000, floor: 2, status: 'maintenance', amenities: ['Heater', 'TV', 'Balcony', 'Mountain View', 'Fireplace'], isActive: true, seasonalRates: [], mealPlans: [], maintenanceHistory: [{ reason: 'Renovating bathroom', startDate: new Date(), status: 'in-progress', notes: 'Tile replacement and plumbing' }], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[1], roomNumber: 'B2', roomType: 'suite', name: 'Hilltop Suite', capacity: 2, basePrice: 18000, floor: 2, status: 'available', amenities: ['Heater', 'TV', 'Fireplace', 'Private Balcony', 'Valley View'], isActive: true, seasonalRates: [], mealPlans: [{ name: 'Half Board', price: 3500 }], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    // Lagoon Eco Lodge
    { property: propIds[2], roomNumber: 'L1', roomType: 'single', name: 'Lagoon Hut', capacity: 1, basePrice: 4500, floor: 1, status: 'available', amenities: ['Fan', 'Mosquito Net', 'Lagoon View'], isActive: true, seasonalRates: [], mealPlans: [], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[2], roomNumber: 'L2', roomType: 'double', name: 'Eco Cabin', capacity: 2, basePrice: 7500, floor: 1, status: 'available', amenities: ['Fan', 'Mosquito Net', 'Deck', 'River View'], isActive: true, seasonalRates: [], mealPlans: [], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[2], roomNumber: 'L3', roomType: 'family', name: 'Treehouse Family', capacity: 4, basePrice: 12000, floor: 2, status: 'available', amenities: ['Fan', 'Mosquito Net', 'Balcony', 'Forest View', 'Extra Beds'], isActive: true, seasonalRates: [], mealPlans: [], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    // Ella Jungle Canopy
    { property: propIds[3], roomNumber: 'C1', roomType: 'double', name: 'Canopy Suite', capacity: 2, basePrice: 16000, floor: 1, status: 'available', amenities: ['Fan', 'Balcony', 'Jungle View', 'Outdoor Shower'], isActive: true, seasonalRates: [], mealPlans: [], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[3], roomNumber: 'C2', roomType: 'suite', name: 'Eagle\'s Nest Suite', capacity: 2, basePrice: 24000, floor: 2, status: 'booked', amenities: ['Fan', 'Deck', 'Mountain View', 'Plunge Pool'], isActive: true, seasonalRates: [], mealPlans: [{ name: 'Half Board', price: 4000 }], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[3], roomNumber: 'C3', roomType: 'family', name: 'Forest Family Lodge', capacity: 4, basePrice: 32000, floor: 1, status: 'available', amenities: ['Fan', 'Balcony', 'Jungle View', 'Kitchenette'], isActive: true, seasonalRates: [], mealPlans: [{ name: 'Full Board', price: 8000 }], maintenanceHistory: [], createdAt: new Date(), updatedAt: new Date() },
  ];
  await db.collection('rooms').insertMany(rooms);
  console.log('Rooms created: 15');

  // ========== BOOKINGS ==========
  const roomDocs = await db.collection('rooms').find({}).toArray();
  const r102 = roomDocs.find(r => r.roomNumber === '102')._id;
  const ra2 = roomDocs.find(r => r.roomNumber === 'A2')._id;

  const bookings = [
    {
      property: propIds[0], room: r102, createdBy: adminId,
      guest: { name: 'James Wilson', email: 'james.wilson@gmail.com', phone: '+44 7911 123456', idType: 'passport', idNumber: 'GB123456789', nationality: 'British' },
      checkIn: new Date('2026-05-25'), checkOut: new Date('2026-05-29'), numberOfGuests: 2, adults: 2, children: 0,
      roomType: 'double',
      pricing: { basePrice: 12000, nights: 4, roomTotal: 48000, mealPlanTotal: 9000, addons: [{ name: 'Airport Transfer', price: 3000 }], discount: 0, tax: 0, totalAmount: 60000 },
      paymentStatus: 'paid', amountPaid: 60000, bookingStatus: 'checked-in',
      specialRequests: 'Late checkout requested', source: 'website', createdAt: new Date(), updatedAt: new Date(),
    },
    {
      property: propIds[0], room: roomDocs.find(r => r.roomNumber === '101')._id, createdBy: manager1Id,
      guest: { name: 'Sarah Chen', email: 'sarah.chen@outlook.com', phone: '+1 555 123 4567', idType: 'passport', idNumber: 'US987654321', nationality: 'American' },
      checkIn: new Date('2026-05-29'), checkOut: new Date('2026-06-02'), numberOfGuests: 1, adults: 1, children: 0,
      roomType: 'single',
      pricing: { basePrice: 8500, nights: 4, roomTotal: 34000, mealPlanTotal: 8000, addons: [], discount: 2000, tax: 0, totalAmount: 40000 },
      paymentStatus: 'partial', amountPaid: 20000, bookingStatus: 'confirmed',
      specialRequests: 'Vegetarian meals', source: 'phone', createdAt: new Date(), updatedAt: new Date(),
    },
    {
      property: propIds[0], room: roomDocs.find(r => r.roomNumber === '201')._id, createdBy: manager1Id,
      guest: { name: 'Raj Patel', email: 'raj@gmail.com', phone: '+91 98765 43210', idType: 'passport', idNumber: 'IN111222333', nationality: 'Indian' },
      checkIn: new Date('2026-06-01'), checkOut: new Date('2026-06-05'), numberOfGuests: 2, adults: 2, children: 0,
      roomType: 'suite',
      pricing: { basePrice: 22000, nights: 4, roomTotal: 88000, mealPlanTotal: 28000, addons: [{ name: 'Flower Arrangement', price: 5000 }], discount: 5000, tax: 0, totalAmount: 116000 },
      paymentStatus: 'partial', amountPaid: 50000, bookingStatus: 'confirmed',
      specialRequests: 'Anniversary celebration - champagne and flowers', source: 'direct', createdAt: new Date(), updatedAt: new Date(),
    },
    {
      property: propIds[1], room: ra2, createdBy: adminId,
      guest: { name: 'Li Wei', email: 'liwei@gmail.com', phone: '+86 138 0000 1234', idType: 'passport', idNumber: 'CN444555666', nationality: 'Chinese' },
      checkIn: new Date('2026-05-20'), checkOut: new Date('2026-05-24'), numberOfGuests: 2, adults: 2, children: 0,
      roomType: 'double',
      pricing: { basePrice: 8000, nights: 4, roomTotal: 32000, mealPlanTotal: 0, addons: [], discount: 0, tax: 0, totalAmount: 32000 },
      paymentStatus: 'paid', amountPaid: 32000, bookingStatus: 'checked-out',
      source: 'website', createdAt: new Date(), updatedAt: new Date(),
    },
    {
      property: propIds[0], room: roomDocs.find(r => r.roomNumber === '202')._id, createdBy: manager2Id,
      guest: { name: 'Emma Thompson', email: 'emma.t@yahoo.com', phone: '+61 412 345 678', idType: 'passport', idNumber: 'AU777888999', nationality: 'Australian' },
      checkIn: new Date('2026-06-10'), checkOut: new Date('2026-06-15'), numberOfGuests: 3, adults: 2, children: 1,
      roomType: 'family',
      pricing: { basePrice: 18000, nights: 5, roomTotal: 90000, mealPlanTotal: 35000, addons: [{ name: 'Kids Activity Pack', price: 3000 }], discount: 0, tax: 0, totalAmount: 128000 },
      paymentStatus: 'pending', amountPaid: 0, bookingStatus: 'confirmed',
      specialRequests: 'Crib needed for toddler', source: 'website', createdAt: new Date(), updatedAt: new Date(),
    },
    {
      property: propIds[2], room: roomDocs.find(r => r.roomNumber === 'L2')._id, createdBy: adminId,
      guest: { name: 'Yuki Tanaka', email: 'yuki.tanaka@gmail.com', phone: '+81 90 1234 5678', idType: 'passport', idNumber: 'JP123123123', nationality: 'Japanese' },
      checkIn: new Date('2026-05-22'), checkOut: new Date('2026-05-26'), numberOfGuests: 2, adults: 2, children: 0,
      roomType: 'double',
      pricing: { basePrice: 7500, nights: 4, roomTotal: 30000, mealPlanTotal: 0, addons: [{ name: 'Kayaking Tour', price: 4000 }], discount: 0, tax: 0, totalAmount: 34000 },
      paymentStatus: 'paid', amountPaid: 34000, bookingStatus: 'checked-out',
      source: 'direct', createdAt: new Date(), updatedAt: new Date(),
    },
    {
      property: propIds[3], room: roomDocs.find(r => r.roomNumber === 'C2')._id, createdBy: adminId,
      guest: { name: 'Sophia Mueller', email: 'sophia.m@web.de', phone: '+49 170 9876543', idType: 'passport', idNumber: 'DE999888777', nationality: 'German' },
      checkIn: new Date('2026-05-26'), checkOut: new Date('2026-05-31'), numberOfGuests: 2, adults: 2, children: 0,
      roomType: 'suite',
      pricing: { basePrice: 24000, nights: 5, roomTotal: 120000, mealPlanTotal: 20000, addons: [], discount: 10000, tax: 0, totalAmount: 130000 },
      paymentStatus: 'paid', amountPaid: 130000, bookingStatus: 'checked-in',
      specialRequests: 'High floor, jungle views', source: 'website', createdAt: new Date(), updatedAt: new Date(),
    },
    {
      property: propIds[0], room: roomDocs.find(r => r.roomNumber === '202')._id, createdBy: manager2Id,
      guest: { name: 'Oliver Smith', email: 'oliver.smith@gmail.com', phone: '+44 7700 900077', idType: 'passport', idNumber: 'GB888777666', nationality: 'British' },
      checkIn: new Date('2026-05-27'), checkOut: new Date('2026-05-30'), numberOfGuests: 3, adults: 2, children: 1,
      roomType: 'family',
      pricing: { basePrice: 18000, nights: 3, roomTotal: 54000, mealPlanTotal: 21000, addons: [], discount: 0, tax: 0, totalAmount: 75000 },
      paymentStatus: 'paid', amountPaid: 75000, bookingStatus: 'checked-in',
      source: 'booking.com', createdAt: new Date(), updatedAt: new Date(),
    },
    {
      property: propIds[1], room: roomDocs.find(r => r.roomNumber === 'B2')._id, createdBy: manager1Id,
      guest: { name: 'Liam Neeson', email: 'liam@taken.com', phone: '+1 212 555 0199', idType: 'passport', idNumber: 'US12349876', nationality: 'Irish' },
      checkIn: new Date('2026-06-05'), checkOut: new Date('2026-06-08'), numberOfGuests: 1, adults: 1, children: 0,
      roomType: 'suite',
      pricing: { basePrice: 18000, nights: 3, roomTotal: 54000, mealPlanTotal: 10500, addons: [], discount: 0, tax: 0, totalAmount: 64500 },
      paymentStatus: 'pending', amountPaid: 0, bookingStatus: 'confirmed',
      source: 'phone', createdAt: new Date(), updatedAt: new Date(),
    },
    {
      property: propIds[2], room: roomDocs.find(r => r.roomNumber === 'L3')._id, createdBy: adminId,
      guest: { name: 'Hans Zimmer', email: 'hans@ost.com', phone: '+49 89 223344', idType: 'passport', idNumber: 'DE555666777', nationality: 'German' },
      checkIn: new Date('2026-06-02'), checkOut: new Date('2026-06-06'), numberOfGuests: 4, adults: 2, children: 2,
      roomType: 'family',
      pricing: { basePrice: 12000, nights: 4, roomTotal: 48000, mealPlanTotal: 0, addons: [{ name: 'Jungle Trekking', price: 6000 }], discount: 4000, tax: 0, totalAmount: 50000 },
      paymentStatus: 'partial', amountPaid: 20000, bookingStatus: 'confirmed',
      source: 'website', createdAt: new Date(), updatedAt: new Date(),
    },
  ];
  await db.collection('bookings').insertMany(bookings);
  console.log('Bookings created: 10');

  // ========== TASKS ==========
  const tasks = [
    { property: propIds[0], title: 'Deep clean Room 102', description: 'Full deep clean required after guest checkout. Sanitize all surfaces.', type: 'housekeeping', priority: 'high', status: 'open', assignedBy: manager1Id, assignedTo: staff1Id, room: r102, subtasks: [{ title: 'Strip beds', completed: false }, { title: 'Clean bathroom', completed: false }, { title: 'Vacuum floor', completed: false }, { title: 'Restock minibar', completed: false }], checklist: [{ item: 'Towels replaced', checked: false }, { item: 'Toiletries restocked', checked: false }, { item: 'Pillows fluffed', checked: false }], dueDate: new Date(), dueTime: '14:00', createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], title: 'Fix AC in Room 101', description: 'Guest reported AC not cooling properly. Check refrigerant levels and filters.', type: 'maintenance', priority: 'urgent', status: 'in-progress', assignedBy: manager1Id, assignedTo: staff2Id, room: roomDocs.find(r => r.roomNumber === '101')._id, subtasks: [{ title: 'Check refrigerant', completed: true }, { title: 'Clean filter', completed: false }, { title: 'Test cooling', completed: false }], checklist: [], dueDate: new Date(), notes: 'Guest checked in tomorrow - urgent fix needed', createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], title: 'Welcome package for Raj Patel', description: 'Prepare anniversary welcome: champagne, flowers, chocolate, handwritten card.', type: 'guest_service', priority: 'medium', status: 'open', assignedBy: manager1Id, assignedTo: staff1Id, room: roomDocs.find(r => r.roomNumber === '201')._id, subtasks: [{ title: 'Order flowers', completed: true }, { title: 'Get champagne', completed: true }, { title: 'Write welcome card', completed: false }, { title: 'Arrange room decoration', completed: false }], checklist: [], dueDate: new Date('2026-06-01'), createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[1], title: 'Monthly fire safety inspection', description: 'Check all fire exits, extinguishers, and alarms in all rooms and common areas.', type: 'inspection', priority: 'high', status: 'open', assignedBy: adminId, assignedTo: staff3Id, subtasks: [], checklist: [{ item: 'Check all extinguishers', checked: false }, { item: 'Test fire alarms', checked: false }, { item: 'Clear all fire exits', checked: false }, { item: 'Update safety log book', checked: false }, { item: 'Check emergency lighting', checked: false }], dueDate: new Date('2026-06-01'), createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], title: 'Pool area deep clean', description: 'Clean pool tiles, check chemical levels, clean loungers and umbrellas.', type: 'housekeeping', priority: 'medium', status: 'completed', assignedBy: manager1Id, assignedTo: staff2Id, completedAt: new Date(), completedBy: staff2Id, subtasks: [], checklist: [], dueDate: new Date(), createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], title: 'Restock lobby amenities', description: 'Replenish welcome drinks, fresh flowers, magazines, and brochures.', type: 'housekeeping', priority: 'low', status: 'open', assignedBy: manager1Id, assignedTo: staff1Id, subtasks: [{ title: 'Buy fresh flowers', completed: false }, { title: 'Order brochures', completed: true }, { title: 'Set up welcome drinks', completed: false }], checklist: [], dueDate: new Date(), createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[2], title: 'Repair kayak paddles', description: 'Three kayak paddles need repair before weekend tours.', type: 'maintenance', priority: 'medium', status: 'open', assignedBy: adminId, assignedTo: staff3Id, subtasks: [], checklist: [{ item: 'Paddle 1 repaired', checked: false }, { item: 'Paddle 2 repaired', checked: false }, { item: 'Paddle 3 repaired', checked: false }, { item: 'Water test all paddles', checked: false }], dueDate: new Date('2026-05-30'), createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], title: 'Prepare Emma Thompson room', description: 'Family room setup: extra bed, baby crib, kids welcome pack.', type: 'guest_service', priority: 'high', status: 'open', assignedBy: manager2Id, assignedTo: staff1Id, room: roomDocs.find(r => r.roomNumber === '202')._id, subtasks: [{ title: 'Setup extra bed', completed: false }, { title: 'Install crib', completed: false }, { title: 'Kids welcome pack', completed: false }], checklist: [], dueDate: new Date('2026-06-09'), createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[3], title: 'Check plunge pool in Room C2', description: 'Ensure the plunge pool water level and chlorine levels are correct before guest arrival.', type: 'maintenance', priority: 'medium', status: 'open', assignedBy: adminId, assignedTo: staff3Id, room: roomDocs.find(r => r.roomNumber === 'C2')._id, subtasks: [], checklist: [], dueDate: new Date(), createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], title: 'Fix balcony door lock in Room 201', description: 'Guest reported the sliding glass door lock is jammed. Inspect and repair.', type: 'maintenance', priority: 'high', status: 'open', assignedBy: manager1Id, assignedTo: staff2Id, room: roomDocs.find(r => r.roomNumber === '201')._id, subtasks: [], checklist: [], dueDate: new Date(), createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[2], title: 'Prepare botanical guide for Hans Zimmer', description: 'Deliver local tree and bird ID book to Treehouse Family cabin L3.', type: 'guest_service', priority: 'low', status: 'completed', assignedBy: adminId, assignedTo: staff3Id, room: roomDocs.find(r => r.roomNumber === 'L3')._id, completedAt: new Date(), completedBy: staff3Id, subtasks: [], checklist: [], dueDate: new Date(), createdAt: new Date(), updatedAt: new Date() },
  ];
  await db.collection('tasks').insertMany(tasks);
  console.log('Tasks created: 11');

  // ========== PAYMENTS ==========
  const bkDocs = await db.collection('bookings').find({}).toArray();
  const payments = [
    { property: propIds[0], booking: bkDocs.find(b => b.guest.email === 'james.wilson@gmail.com')._id, amount: 60000, currency: 'LKR', method: 'card', type: 'full', status: 'completed', invoiceNumber: 'INV-2026-001', gateway: { name: 'stripe', transactionId: 'pi_1234567890' }, paidAt: new Date('2026-05-24'), recordedBy: adminId, createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], booking: bkDocs.find(b => b.guest.email === 'sarah.chen@outlook.com')._id, amount: 20000, currency: 'LKR', method: 'bank_transfer', type: 'advance', status: 'completed', invoiceNumber: 'INV-2026-002', paidAt: new Date('2026-05-27'), recordedBy: manager1Id, createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], booking: bkDocs.find(b => b.guest.email === 'raj@gmail.com')._id, amount: 50000, currency: 'LKR', method: 'online', type: 'advance', status: 'completed', invoiceNumber: 'INV-2026-003', gateway: { name: 'payhere', transactionId: 'PH-987654' }, paidAt: new Date('2026-05-26'), recordedBy: manager1Id, createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[1], booking: bkDocs.find(b => b.guest.email === 'liwei@gmail.com')._id, amount: 32000, currency: 'LKR', method: 'online', type: 'full', status: 'completed', invoiceNumber: 'INV-2026-004', gateway: { name: 'stripe', transactionId: 'pi_0987654321' }, paidAt: new Date('2019-05-19'), recordedBy: adminId, createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[2], booking: bkDocs.find(b => b.guest.email === 'yuki.tanaka@gmail.com')._id, amount: 34000, currency: 'LKR', method: 'cash', type: 'full', status: 'completed', invoiceNumber: 'INV-2026-005', paidAt: new Date('2026-05-22'), recordedBy: adminId, createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[3], booking: bkDocs.find(b => b.guest.email === 'sophia.m@web.de')._id, amount: 130000, currency: 'LKR', method: 'card', type: 'full', status: 'completed', invoiceNumber: 'INV-2026-006', gateway: { name: 'stripe', transactionId: 'pi_abc123xyz' }, paidAt: new Date('2026-05-26'), recordedBy: adminId, createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[0], booking: bkDocs.find(b => b.guest.email === 'oliver.smith@gmail.com')._id, amount: 75000, currency: 'LKR', method: 'online', type: 'full', status: 'completed', invoiceNumber: 'INV-2026-007', gateway: { name: 'stripe', transactionId: 'pi_def456uvw' }, paidAt: new Date('2026-05-27'), recordedBy: manager2Id, createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[2], booking: bkDocs.find(b => b.guest.email === 'hans@ost.com')._id, amount: 20000, currency: 'LKR', method: 'card', type: 'advance', status: 'completed', invoiceNumber: 'INV-2026-008', gateway: { name: 'stripe', transactionId: 'pi_ghi789opq' }, paidAt: new Date('2026-05-28'), recordedBy: adminId, createdAt: new Date(), updatedAt: new Date() },
  ];
  await db.collection('payments').insertMany(payments);
  console.log('Payments created: 8');

  // ========== FEEDBACK ==========
  const feedback = [
    { property: propIds[0], booking: bkDocs.find(b => b.guest.email === 'james.wilson@gmail.com')._id, guestName: 'James Wilson', guestEmail: 'james.wilson@gmail.com', rating: 5, title: 'Great beachfront location!', comment: 'Beautiful ocean views and excellent service. The staff was very attentive.', categories: { cleanliness: 5, comfort: 5, location: 5, service: 5, value: 5 }, isPublic: true, createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[1], booking: bkDocs.find(b => b.guest.email === 'liwei@gmail.com')._id, guestName: 'Li Wei', guestEmail: 'liwei@gmail.com', rating: 5, title: 'Amazing mountain views!', comment: 'The room was cozy and the staff were incredibly friendly. The fireplace was a nice touch. Will definitely come back!', categories: { cleanliness: 5, comfort: 5, location: 5, service: 5, value: 4 }, isPublic: true, createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[2], booking: bkDocs.find(b => b.guest.email === 'yuki.tanaka@gmail.com')._id, guestName: 'Yuki Tanaka', guestEmail: 'yuki.tanaka@gmail.com', rating: 4, title: 'Beautiful nature experience', comment: 'Loved the kayaking and bird watching. The eco lodge is very unique. Room was basic but clean.', categories: { cleanliness: 4, comfort: 3, location: 5, service: 4, value: 4 }, isPublic: true, createdAt: new Date(), updatedAt: new Date() },
    { property: propIds[3], booking: bkDocs.find(b => b.guest.email === 'sophia.m@web.de')._id, guestName: 'Sophia Mueller', guestEmail: 'sophia.m@web.de', rating: 5, title: 'Incredible jungle retreat', comment: 'Sleeping under the canopy was magical. Plunge pool was clean and refreshing. Five stars all the way!', categories: { cleanliness: 5, comfort: 5, location: 5, service: 5, value: 5 }, isPublic: true, createdAt: new Date(), updatedAt: new Date() },
  ];
  await db.collection('feedbacks').insertMany(feedback);
  console.log('Feedback created: 4');

  // ========== NOTIFICATIONS ==========
  const notifications = [
    { recipient: adminId, type: 'booking_confirmed', title: 'New Booking', message: 'Emma Thompson booked Palm Family Room for Jun 10-15', data: {}, channels: { inApp: true }, read: false, sent: true, sentAt: new Date(), createdAt: new Date(), updatedAt: new Date() },
    { recipient: adminId, type: 'payment_received', title: 'Payment Received', message: 'LKR 34,000 received from Yuki Tanaka via cash', data: {}, channels: { inApp: true }, read: true, readAt: new Date(), sent: true, sentAt: new Date(), createdAt: new Date(), updatedAt: new Date() },
    { recipient: manager1Id, type: 'task_assigned', title: 'Urgent Task', message: 'Fix AC in Room 101 - guest checking in tomorrow', data: {}, channels: { inApp: true }, read: false, sent: true, sentAt: new Date(), createdAt: new Date(), updatedAt: new Date() },
    { recipient: staff1Id, type: 'task_assigned', title: 'New Task', message: 'Deep clean Room 102 after checkout', data: {}, channels: { inApp: true }, read: true, readAt: new Date(), sent: true, sentAt: new Date(), createdAt: new Date(), updatedAt: new Date() },
    { recipient: staff1Id, type: 'task_assigned', title: 'Guest Service', message: 'Prepare welcome package for Raj Patel - Anniversary', data: {}, channels: { inApp: true }, read: false, sent: true, sentAt: new Date(), createdAt: new Date(), updatedAt: new Date() },
  ];
  await db.collection('notifications').insertMany(notifications);
  console.log('Notifications created: 5');

  // ========== AUDIT LOGS ==========
  const auditLogs = [
    { user: adminId, action: 'register', entity: 'User', description: 'Admin registered', status: 'success', createdAt: new Date(), updatedAt: new Date() },
    { user: adminId, action: 'create', entity: 'Property', description: 'Created Seaside Resort & Spa', status: 'success', createdAt: new Date(), updatedAt: new Date() },
    { user: adminId, action: 'create', entity: 'Property', description: 'Created Mountain View Inn', status: 'success', createdAt: new Date(), updatedAt: new Date() },
    { user: adminId, action: 'create', entity: 'Booking', description: 'Booking for James Wilson', status: 'success', createdAt: new Date(), updatedAt: new Date() },
    { user: manager1Id, action: 'create', entity: 'Booking', description: 'Booking for Sarah Chen', status: 'success', createdAt: new Date(), updatedAt: new Date() },
  ];
  await db.collection('auditlogs').insertMany(auditLogs);
  console.log('Audit logs created: 5');

  console.log('\n========================================');
  console.log('SEED COMPLETE - All data created!');
  console.log('========================================');
  console.log('');
  console.log('CREDENTIALS (all passwords: password123):');
  console.log('');
  console.log('Admin:    kamal@easeinn.com');
  console.log('Manager:  nadeesha@easeinn.com');
  console.log('Manager:  ashan@easeinn.com');
  console.log('Staff:    dilshan@easeinn.com');
  console.log('Staff:    kavindu@easeinn.com');
  console.log('Staff:    tharaka@easeinn.com');
  console.log('');
  console.log('DATA SUMMARY:');
  console.log('Users: 6');
  console.log('Properties: 4');
  console.log('Rooms: 15');
  console.log('Bookings: 10');
  console.log('Tasks: 11');
  console.log('Payments: 8');
  console.log('Feedback: 3');
  console.log('Notifications: 5');
  console.log('Audit Logs: 5');

  await mongoose.disconnect();
}

seed().catch(e => { console.error(e); process.exit(1); });

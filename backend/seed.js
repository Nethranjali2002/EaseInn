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

  const pw = await bcrypt.hash('password123', 12);

  const now = new Date();

  // IDs
  const adminId = new mongoose.Types.ObjectId();
  const mgr1Id = new mongoose.Types.ObjectId();
  const mgr2Id = new mongoose.Types.ObjectId();
  const staff1Id = new mongoose.Types.ObjectId();
  const staff2Id = new mongoose.Types.ObjectId();
  const staff3Id = new mongoose.Types.ObjectId();

  // ========== USERS ==========
  const users = [
    {
      _id: adminId, code: 'EMP-0001', name: 'Kamal Perera', email: 'kamal@easeinn.com',
      password: pw, role: 'admin', phone: '+94771234567', gender: 'Male',
      dateOfBirth: '1985-03-15', nicPassport: '851234567V', employeeId: 'EMP-0001',
      address: '42 Temple Road, Colombo 03', city: 'Colombo', district: 'Colombo', postalCode: '00300',
      joinDate: '2024-01-01', employmentType: 'Full Time', status: 'Active',
      emergencyName: 'Nandini Perera', emergencyRelationship: 'Wife', emergencyPhone: '+94779876543',
      isActive: true, lastLogin: new Date(), createdAt: now, updatedAt: now,
    },
    {
      _id: mgr1Id, code: 'EMP-0002', name: 'Nadeesha Silva', email: 'nadeesha@easeinn.com',
      password: pw, role: 'manager', phone: '+94712345678', gender: 'Female',
      dateOfBirth: '1990-07-22', nicPassport: '901234567V', employeeId: 'EMP-0002',
      address: '15 Galle Road, Mount Lavinia', city: 'Mount Lavinia', district: 'Colombo', postalCode: '10370',
      joinDate: '2024-03-15', employmentType: 'Full Time', status: 'Active',
      emergencyName: 'Sunil Silva', emergencyRelationship: 'Husband', emergencyPhone: '+94718765432',
      property: null, isActive: true, lastLogin: new Date(), createdAt: now, updatedAt: now,
    },
    {
      _id: mgr2Id, code: 'EMP-0003', name: 'Ashan Fernando', email: 'ashan@easeinn.com',
      password: pw, role: 'manager', phone: '+94723456789', gender: 'Male',
      dateOfBirth: '1988-11-10', nicPassport: '881234567V', employeeId: 'EMP-0003',
      address: '88 Kandy Road, Peradeniya', city: 'Kandy', district: 'Kandy', postalCode: '20400',
      joinDate: '2024-06-01', employmentType: 'Full Time', status: 'Active',
      emergencyName: 'Dilini Fernando', emergencyRelationship: 'Wife', emergencyPhone: '+94721112233',
      property: null, isActive: true, lastLogin: new Date(), createdAt: now, updatedAt: now,
    },
    {
      _id: staff1Id, code: 'EMP-0004', name: 'Dilshan Rajapaksa', email: 'dilshan@easeinn.com',
      password: pw, role: 'staff', phone: '+94734567890', gender: 'Male',
      dateOfBirth: '1995-02-28', nicPassport: '951234567V', employeeId: 'EMP-0004',
      address: '22 Main Street, Galle', city: 'Galle', district: 'Galle', postalCode: '80000',
      joinDate: '2024-09-01', employmentType: 'Full Time', status: 'Active',
      emergencyName: 'Kamala Rajapaksa', emergencyRelationship: 'Mother', emergencyPhone: '+94731112233',
      property: null, isActive: true, lastLogin: new Date(), createdAt: now, updatedAt: now,
    },
    {
      _id: staff2Id, code: 'EMP-0005', name: 'Kavindu Bandara', email: 'kavindu@easeinn.com',
      password: pw, role: 'staff', phone: '+94745678901', gender: 'Male',
      dateOfBirth: '1993-06-05', nicPassport: '931234567V', employeeId: 'EMP-0005',
      address: '5 Lake Drive, Nuwara Eliya', city: 'Nuwara Eliya', district: 'Nuwara Eliya', postalCode: '22200',
      joinDate: '2024-10-15', employmentType: 'Full Time', status: 'Active',
      emergencyName: 'Sumith Bandara', emergencyRelationship: 'Father', emergencyPhone: '+94741112233',
      property: null, isActive: true, lastLogin: new Date(), createdAt: now, updatedAt: now,
    },
    {
      _id: staff3Id, code: 'EMP-0006', name: 'Tharaka Mendis', email: 'tharaka@easeinn.com',
      password: pw, role: 'staff', phone: '+94756789012', gender: 'Male',
      dateOfBirth: '1997-09-18', nicPassport: '971234567V', employeeId: 'EMP-0006',
      address: '33 Station Road, Ella', city: 'Ella', district: 'Badulla', postalCode: '90090',
      joinDate: '2025-01-10', employmentType: 'Full Time', status: 'Active',
      emergencyName: 'Lakshmi Mendis', emergencyRelationship: 'Sister', emergencyPhone: '+94751112233',
      property: null, isActive: true, createdAt: now, updatedAt: now,
    },
  ];
  await db.collection('users').insertMany(users);
  console.log('Users created: 6');

  // ========== PROPERTIES ==========
  const properties = [
    {
      code: 'PR-0001', owner: adminId, name: 'Seaside Resort & Spa',
      description: 'Luxury beachfront resort with stunning ocean views, world-class spa, and fine dining in Galle.',
      address: { street: '123 Beach Road', city: 'Galle', state: 'Southern', country: 'Sri Lanka', zipCode: '80000' },
      contact: { phone: '+94912234567', email: 'info@seasideresort.lk' },
      amenities: ['Swimming Pool', 'Spa', 'Restaurant', 'Free WiFi', 'Beach Access', 'Parking', 'Gym', 'Room Service'],
      totalRooms: 5, taxRate: 10, isActive: true,
      logo: '/uploads/images/resort_logo.png',
      coverImage: '/uploads/images/resort_cover.png',
      images: ['/uploads/images/room_image.png', '/uploads/images/room_image_2.png', '/uploads/images/room_image_3.png'],
      createdAt: now, updatedAt: now,
    },
    {
      code: 'PR-0002', owner: adminId, name: 'Mountain View Inn',
      description: 'A cozy mountain retreat surrounded by lush tea plantations in the cool hills of Nuwara Eliya.',
      address: { street: '45 Hill Station Road', city: 'Nuwara Eliya', state: 'Central', country: 'Sri Lanka', zipCode: '22200' },
      contact: { phone: '+94522221234', email: 'info@mountainview.lk' },
      amenities: ['Garden', 'Fireplace', 'Free WiFi', 'Hiking Tours', 'Restaurant', 'Library'],
      totalRooms: 4, taxRate: 10, isActive: true,
      logo: '/uploads/images/resort_logo.png',
      coverImage: '/uploads/images/resort_cover.png',
      images: ['/uploads/images/room_image.png', '/uploads/images/room_image_2.png'],
      createdAt: now, updatedAt: now,
    },
    {
      code: 'PR-0003', owner: adminId, name: 'Lagoon Eco Lodge',
      description: 'Eco-friendly lodge on the banks of a scenic lagoon. Perfect for nature lovers and bird watchers.',
      address: { street: '12 Lagoon Road', city: 'Kitulgala', state: 'Western', country: 'Sri Lanka', zipCode: '10720' },
      contact: { phone: '+94362256789', email: 'info@lagooneco.lk' },
      amenities: ['Kayaking', 'Bird Watching', 'Campfire', 'Free WiFi', 'Organic Restaurant', 'Nature Trails'],
      totalRooms: 3, taxRate: 10, isActive: true,
      logo: '/uploads/images/resort_logo.png',
      coverImage: '/uploads/images/resort_cover.png',
      images: ['/uploads/images/room_image_2.png', '/uploads/images/room_image_3.png'],
      createdAt: now, updatedAt: now,
    },
    {
      code: 'PR-0004', owner: adminId, name: 'Ella Jungle Canopy',
      description: 'Luxe tents and canopy cabins suspended above the rainforest canopy. Experience wilderness in style.',
      address: { street: 'Wellawaya Road', city: 'Ella', state: 'Uva', country: 'Sri Lanka', zipCode: '90090' },
      contact: { phone: '+94572229876', email: 'info@ellacanopy.lk' },
      amenities: ['Hiking Trails', 'Infinity Pool', 'Free WiFi', 'Yoga Deck', 'Spa', 'Restaurant'],
      totalRooms: 3, taxRate: 10, isActive: true,
      logo: '/uploads/images/resort_logo.png',
      coverImage: '/uploads/images/resort_cover.png',
      images: ['/uploads/images/room_image.png', '/uploads/images/room_image_3.png'],
      createdAt: now, updatedAt: now,
    },
  ];
  const propResult = await db.collection('properties').insertMany(properties);
  const pIds = Object.values(propResult.insertedIds);
  console.log('Properties created: 4');

  // Assign properties to managers
  await db.collection('users').updateOne({ _id: mgr1Id }, { $set: { property: pIds[0] } });
  await db.collection('users').updateOne({ _id: mgr2Id }, { $set: { property: pIds[1] } });
  await db.collection('users').updateOne({ _id: staff1Id }, { $set: { property: pIds[0] } });
  await db.collection('users').updateOne({ _id: staff2Id }, { $set: { property: pIds[1] } });
  await db.collection('users').updateOne({ _id: staff3Id }, { $set: { property: pIds[2] } });

  // ========== ROOMS ==========
  const rooms = [
    // Seaside Resort (5 rooms)
    { code: 'RM-0001', property: pIds[0], roomNumber: '101', roomType: 'single', name: 'Ocean Breeze Single', capacity: 1, basePrice: 8500, floor: 1, status: 'available', amenities: ['AC', 'TV', 'Mini Bar', 'Sea View'], isActive: true, images: ['/uploads/images/room_image.png', '/uploads/images/room_image_2.png'], mealPlans: [{ name: 'Bed & Breakfast', price: 2000 }], createdAt: now, updatedAt: now },
    { code: 'RM-0002', property: pIds[0], roomNumber: '102', roomType: 'double', name: 'Sunset Double', capacity: 2, basePrice: 12000, floor: 1, status: 'booked', amenities: ['AC', 'TV', 'Mini Bar', 'Balcony'], isActive: true, images: ['/uploads/images/room_image.png', '/uploads/images/room_image_3.png'], mealPlans: [{ name: 'Half Board', price: 4500 }], createdAt: now, updatedAt: now },
    { code: 'RM-0003', property: pIds[0], roomNumber: '201', roomType: 'suite', name: 'Coral Suite', capacity: 2, basePrice: 22000, floor: 2, status: 'available', amenities: ['AC', 'TV', 'Jacuzzi', 'Ocean View', 'Living Area'], isActive: true, images: ['/uploads/images/room_image_2.png', '/uploads/images/room_image_3.png'], mealPlans: [{ name: 'Full Board', price: 7000 }], createdAt: now, updatedAt: now },
    { code: 'RM-0004', property: pIds[0], roomNumber: '202', roomType: 'family', name: 'Palm Family Room', capacity: 4, basePrice: 18000, floor: 2, status: 'available', amenities: ['AC', 'TV', 'Extra Beds', 'Kids Area'], isActive: true, images: ['/uploads/images/room_image.png', '/uploads/images/room_image_2.png', '/uploads/images/room_image_3.png'], mealPlans: [{ name: 'Full Board', price: 7000 }], createdAt: now, updatedAt: now },
    { code: 'RM-0005', property: pIds[0], roomNumber: '301', roomType: 'presidential', name: 'Presidential Suite', capacity: 3, basePrice: 45000, floor: 3, status: 'available', amenities: ['AC', 'Jacuzzi', 'Private Pool', 'Butler Service'], isActive: true, images: ['/uploads/images/room_image_3.png'], mealPlans: [{ name: 'All Inclusive', price: 12000 }], createdAt: now, updatedAt: now },
    // Mountain View (4 rooms)
    { code: 'RM-0006', property: pIds[1], roomNumber: 'A1', roomType: 'single', name: 'Garden View Single', capacity: 1, basePrice: 5500, floor: 1, status: 'available', amenities: ['Heater', 'TV', 'Garden View'], isActive: true, images: ['/uploads/images/room_image.png', '/uploads/images/room_image_2.png'], createdAt: now, updatedAt: now },
    { code: 'RM-0007', property: pIds[1], roomNumber: 'A2', roomType: 'double', name: 'Tea Plantation Double', capacity: 2, basePrice: 8000, floor: 1, status: 'booked', amenities: ['Heater', 'TV', 'Fireplace', 'Tea View'], isActive: true, images: ['/uploads/images/room_image_2.png', '/uploads/images/room_image_3.png'], createdAt: now, updatedAt: now },
    { code: 'RM-0008', property: pIds[1], roomNumber: 'B1', roomType: 'deluxe', name: 'Mountain Deluxe', capacity: 2, basePrice: 15000, floor: 2, status: 'maintenance', amenities: ['Heater', 'TV', 'Balcony', 'Mountain View'], isActive: true, images: ['/uploads/images/room_image.png', '/uploads/images/room_image_3.png'], maintenanceHistory: [{ reason: 'Bathroom renovation', startDate: new Date(), status: 'in-progress', notes: 'Tile replacement' }], createdAt: now, updatedAt: now },
    { code: 'RM-0009', property: pIds[1], roomNumber: 'B2', roomType: 'suite', name: 'Hilltop Suite', capacity: 2, basePrice: 18000, floor: 2, status: 'available', amenities: ['Heater', 'TV', 'Fireplace', 'Valley View'], isActive: true, images: ['/uploads/images/room_image.png', '/uploads/images/room_image_2.png', '/uploads/images/room_image_3.png'], mealPlans: [{ name: 'Half Board', price: 3500 }], createdAt: now, updatedAt: now },
    // Lagoon Eco Lodge (3 rooms)
    { code: 'RM-0010', property: pIds[2], roomNumber: 'L1', roomType: 'single', name: 'Lagoon Hut', capacity: 1, basePrice: 4500, floor: 1, status: 'available', amenities: ['Fan', 'Mosquito Net', 'Lagoon View'], isActive: true, createdAt: now, updatedAt: now },
    { code: 'RM-0011', property: pIds[2], roomNumber: 'L2', roomType: 'double', name: 'Eco Cabin', capacity: 2, basePrice: 7500, floor: 1, status: 'available', amenities: ['Fan', 'Deck', 'River View'], isActive: true, createdAt: now, updatedAt: now },
    { code: 'RM-0012', property: pIds[2], roomNumber: 'L3', roomType: 'family', name: 'Treehouse Family', capacity: 4, basePrice: 12000, floor: 2, status: 'available', amenities: ['Fan', 'Balcony', 'Forest View', 'Extra Beds'], isActive: true, createdAt: now, updatedAt: now },
    // Ella Jungle Canopy (3 rooms)
    { code: 'RM-0013', property: pIds[3], roomNumber: 'C1', roomType: 'double', name: 'Canopy Suite', capacity: 2, basePrice: 16000, floor: 1, status: 'available', amenities: ['Fan', 'Balcony', 'Jungle View'], isActive: true, createdAt: now, updatedAt: now },
    { code: 'RM-0014', property: pIds[3], roomNumber: 'C2', roomType: 'suite', name: "Eagle's Nest Suite", capacity: 2, basePrice: 24000, floor: 2, status: 'booked', amenities: ['Fan', 'Deck', 'Plunge Pool', 'Mountain View'], isActive: true, mealPlans: [{ name: 'Half Board', price: 4000 }], createdAt: now, updatedAt: now },
    { code: 'RM-0015', property: pIds[3], roomNumber: 'C3', roomType: 'family', name: 'Forest Family Lodge', capacity: 4, basePrice: 32000, floor: 1, status: 'available', amenities: ['Fan', 'Balcony', 'Kitchenette'], isActive: true, mealPlans: [{ name: 'Full Board', price: 8000 }], createdAt: now, updatedAt: now },
  ];
  await db.collection('rooms').insertMany(rooms);
  console.log('Rooms created: 15');

  // ========== BOOKINGS ==========
  const roomDocs = await db.collection('rooms').find({}).toArray();
  const r102 = roomDocs.find(r => r.roomNumber === '102')._id;
  const r101 = roomDocs.find(r => r.roomNumber === '101')._id;
  const r201 = roomDocs.find(r => r.roomNumber === '201')._id;
  const r202 = roomDocs.find(r => r.roomNumber === '202')._id;
  const ra2 = roomDocs.find(r => r.roomNumber === 'A2')._id;
  const rb2 = roomDocs.find(r => r.roomNumber === 'B2')._id;
  const rl2 = roomDocs.find(r => r.roomNumber === 'L2')._id;
  const rl3 = roomDocs.find(r => r.roomNumber === 'L3')._id;
  const rc2 = roomDocs.find(r => r.roomNumber === 'C2')._id;

  const bookings = [
    {
      code: 'BK-260606-0001', property: pIds[0], room: r102, createdBy: adminId,
      guest: { name: 'Kasun Wickramasinghe', email: 'kasun@gmail.com', phone: '+94711112222', idType: 'nic', idNumber: '911234567V', nationality: 'Sri Lankan', address: '10 Lake Drive, Colombo 07' },
      checkIn: new Date('2026-06-01'), checkOut: new Date('2026-06-05'), numberOfGuests: 2, adults: 2, children: 0, roomType: 'double',
      pricing: { basePrice: 12000, nights: 4, roomTotal: 48000, mealPlanTotal: 9000, addons: [], discount: 0, tax: 5700, totalAmount: 62700 },
      paymentStatus: 'paid', amountPaid: 62700, bookingStatus: 'checked-in',
      specialRequests: 'Late checkout', source: 'direct', createdAt: now, updatedAt: now,
    },
    {
      code: 'BK-260606-0002', property: pIds[0], room: r101, createdBy: mgr1Id,
      guest: { name: 'Amara Jayawardena', email: 'amara@gmail.com', phone: '+94722223333', idType: 'nic', idNumber: '881234567V', nationality: 'Sri Lankan', address: '25 Temple Road, Kandy' },
      checkIn: new Date('2026-06-06'), checkOut: new Date('2026-06-09'), numberOfGuests: 1, adults: 1, children: 0, roomType: 'single',
      pricing: { basePrice: 8500, nights: 3, roomTotal: 25500, mealPlanTotal: 6000, addons: [], discount: 0, tax: 3150, totalAmount: 34650 },
      paymentStatus: 'partial', amountPaid: 15000, bookingStatus: 'confirmed',
      source: 'phone', createdAt: now, updatedAt: now,
    },
    {
      code: 'BK-260606-0003', property: pIds[0], room: r201, createdBy: mgr1Id,
      guest: { name: 'Ravi de Silva', email: 'ravi.desilva@gmail.com', phone: '+94773334444', idType: 'nic', idNumber: '851234567V', nationality: 'Sri Lankan', address: '5 Galle Face, Colombo 01' },
      checkIn: new Date('2026-06-10'), checkOut: new Date('2026-06-14'), numberOfGuests: 2, adults: 2, children: 0, roomType: 'suite',
      pricing: { basePrice: 22000, nights: 4, roomTotal: 88000, mealPlanTotal: 28000, addons: [{ name: 'Flower Arrangement', price: 5000 }], discount: 5000, tax: 11600, totalAmount: 127600 },
      paymentStatus: 'partial', amountPaid: 50000, bookingStatus: 'confirmed',
      specialRequests: 'Anniversary celebration', source: 'website', createdAt: now, updatedAt: now,
    },
    {
      code: 'BK-260606-0004', property: pIds[1], room: ra2, createdBy: adminId,
      guest: { name: 'Nimal Fernando', email: 'nimal@gmail.com', phone: '+94784445555', idType: 'nic', idNumber: '901234567V', nationality: 'Sri Lankan', address: '88 Kandy Road, Peradeniya' },
      checkIn: new Date('2026-05-20'), checkOut: new Date('2026-05-24'), numberOfGuests: 2, adults: 2, children: 0, roomType: 'double',
      pricing: { basePrice: 8000, nights: 4, roomTotal: 32000, mealPlanTotal: 0, addons: [], discount: 0, tax: 3200, totalAmount: 35200 },
      paymentStatus: 'paid', amountPaid: 35200, bookingStatus: 'checked-out',
      source: 'direct', createdAt: now, updatedAt: now,
    },
    {
      code: 'BK-260606-0005', property: pIds[0], room: r202, createdBy: mgr2Id,
      guest: { name: 'Dinesh Herath', email: 'dinesh@gmail.com', phone: '+94795556666', idType: 'nic', idNumber: '871234567V', nationality: 'Sri Lankan', address: '15 Beach Road, Unawatuna' },
      checkIn: new Date('2026-06-12'), checkOut: new Date('2026-06-16'), numberOfGuests: 4, adults: 2, children: 2, roomType: 'family',
      pricing: { basePrice: 18000, nights: 4, roomTotal: 72000, mealPlanTotal: 28000, addons: [{ name: 'Kids Activity Pack', price: 3000 }], discount: 0, tax: 10300, totalAmount: 113300 },
      paymentStatus: 'pending', amountPaid: 0, bookingStatus: 'confirmed',
      specialRequests: 'Crib needed for toddler', source: 'website', createdAt: now, updatedAt: now,
    },
    {
      code: 'BK-260606-0006', property: pIds[2], room: rl2, createdBy: adminId,
      guest: { name: 'Priya Nair', email: 'priya.nair@gmail.com', phone: '+94766667777', idType: 'passport', idNumber: 'IN555666777', nationality: 'Indian', address: 'Mumbai, India' },
      checkIn: new Date('2026-05-22'), checkOut: new Date('2026-05-26'), numberOfGuests: 2, adults: 2, children: 0, roomType: 'double',
      pricing: { basePrice: 7500, nights: 4, roomTotal: 30000, mealPlanTotal: 0, addons: [{ name: 'Kayaking Tour', price: 4000 }], discount: 0, tax: 3400, totalAmount: 37400 },
      paymentStatus: 'paid', amountPaid: 37400, bookingStatus: 'checked-out',
      source: 'direct', createdAt: now, updatedAt: now,
    },
    {
      code: 'BK-260606-0007', property: pIds[3], room: rc2, createdBy: adminId,
      guest: { name: 'Tom Henderson', email: 'tom.h@gmail.com', phone: '+447700123456', idType: 'passport', idNumber: 'GB888777666', nationality: 'British', address: 'London, UK' },
      checkIn: new Date('2026-06-01'), checkOut: new Date('2026-06-06'), numberOfGuests: 2, adults: 2, children: 0, roomType: 'suite',
      pricing: { basePrice: 24000, nights: 5, roomTotal: 120000, mealPlanTotal: 20000, addons: [], discount: 10000, tax: 13000, totalAmount: 143000 },
      paymentStatus: 'paid', amountPaid: 143000, bookingStatus: 'checked-in',
      specialRequests: 'High floor, jungle views', source: 'website', createdAt: now, updatedAt: now,
    },
    {
      code: 'BK-260606-0008', property: pIds[0], room: r202, createdBy: mgr2Id,
      guest: { name: 'Sanduni Perera', email: 'sanduni@gmail.com', phone: '+94707778888', idType: 'nic', idNumber: '921234567V', nationality: 'Sri Lankan', address: '33 Main Street, Matara' },
      checkIn: new Date('2026-06-20'), checkOut: new Date('2026-06-23'), numberOfGuests: 3, adults: 2, children: 1, roomType: 'family',
      pricing: { basePrice: 18000, nights: 3, roomTotal: 54000, mealPlanTotal: 21000, addons: [], discount: 0, tax: 7500, totalAmount: 82500 },
      paymentStatus: 'pending', amountPaid: 0, bookingStatus: 'pending-payment',
      source: 'booking.com', createdAt: now, updatedAt: now,
    },
    {
      code: 'BK-260606-0009', property: pIds[2], room: rl3, createdBy: adminId,
      guest: { name: 'Hans Muller', email: 'hans.m@gmail.com', phone: '+49170123456', idType: 'passport', idNumber: 'DE555666777', nationality: 'German', address: 'Munich, Germany' },
      checkIn: new Date('2026-06-05'), checkOut: new Date('2026-06-09'), numberOfGuests: 4, adults: 2, children: 2, roomType: 'family',
      pricing: { basePrice: 12000, nights: 4, roomTotal: 48000, mealPlanTotal: 0, addons: [{ name: 'Jungle Trekking', price: 6000 }], discount: 4000, tax: 5000, totalAmount: 55000 },
      paymentStatus: 'partial', amountPaid: 25000, bookingStatus: 'confirmed',
      source: 'website', createdAt: now, updatedAt: now,
    },
    {
      code: 'BK-260606-0010', property: pIds[1], room: rb2, createdBy: mgr1Id,
      guest: { name: 'Chathuri Wickramasinghe', email: 'chathuri@gmail.com', phone: '+94718889999', idType: 'nic', idNumber: '941234567V', nationality: 'Sri Lankan', address: '7 Lake Gregory, Nuwara Eliya' },
      checkIn: new Date('2026-06-08'), checkOut: new Date('2026-06-11'), numberOfGuests: 2, adults: 2, children: 0, roomType: 'suite',
      pricing: { basePrice: 18000, nights: 3, roomTotal: 54000, mealPlanTotal: 10500, addons: [], discount: 0, tax: 6450, totalAmount: 70950 },
      paymentStatus: 'pending', amountPaid: 0, bookingStatus: 'confirmed',
      source: 'phone', createdAt: now, updatedAt: now,
    },
  ];
  await db.collection('bookings').insertMany(bookings);
  console.log('Bookings created: 10');

  // ========== TASKS ==========
  const tasks = [
    { code: 'TSK-260606-0001', property: pIds[0], title: 'Deep clean Room 102', description: 'Full deep clean after guest checkout.', type: 'housekeeping', priority: 'high', status: 'open', assignedBy: mgr1Id, assignedTo: staff1Id, room: r102, subtasks: [{ title: 'Strip beds', completed: false }, { title: 'Clean bathroom', completed: false }, { title: 'Vacuum floor', completed: false }], dueDate: now, dueTime: '14:00', createdAt: now, updatedAt: now },
    { code: 'TSK-260606-0002', property: pIds[0], title: 'Fix AC in Room 101', description: 'Guest reported AC not cooling.', type: 'maintenance', priority: 'urgent', status: 'in-progress', assignedBy: mgr1Id, assignedTo: staff2Id, room: r101, subtasks: [{ title: 'Check refrigerant', completed: true }, { title: 'Clean filter', completed: false }], dueDate: now, notes: 'Urgent - guest checking in tomorrow', createdAt: now, updatedAt: now },
    { code: 'TSK-260606-0003', property: pIds[0], title: 'Welcome package for Ravi de Silva', description: 'Anniversary welcome: champagne, flowers.', type: 'guest_service', priority: 'medium', status: 'open', assignedBy: mgr1Id, assignedTo: staff1Id, room: r201, subtasks: [{ title: 'Order flowers', completed: true }, { title: 'Write welcome card', completed: false }], dueDate: new Date('2026-06-09'), createdAt: now, updatedAt: now },
    { code: 'TSK-260606-0004', property: pIds[1], title: 'Monthly fire safety inspection', description: 'Check all fire exits and extinguishers.', type: 'inspection', priority: 'high', status: 'open', assignedBy: adminId, assignedTo: staff3Id, checklist: [{ item: 'Check extinguishers', checked: false }, { item: 'Test fire alarms', checked: false }, { item: 'Clear fire exits', checked: false }], dueDate: new Date('2026-06-15'), createdAt: now, updatedAt: now },
    { code: 'TSK-260606-0005', property: pIds[0], title: 'Pool area deep clean', description: 'Clean tiles and check chemicals.', type: 'housekeeping', priority: 'medium', status: 'completed', assignedBy: mgr1Id, assignedTo: staff2Id, completedAt: new Date(), completedBy: staff2Id, dueDate: now, createdAt: now, updatedAt: now },
    { code: 'TSK-260606-0006', property: pIds[2], title: 'Repair kayak paddles', description: 'Three paddles need repair before weekend tours.', type: 'maintenance', priority: 'medium', status: 'open', assignedBy: adminId, assignedTo: staff3Id, checklist: [{ item: 'Paddle 1 repaired', checked: false }, { item: 'Paddle 2 repaired', checked: false }, { item: 'Paddle 3 repaired', checked: false }], dueDate: new Date('2026-06-10'), createdAt: now, updatedAt: now },
    { code: 'TSK-260606-0007', property: pIds[0], title: 'Prepare Dinesh Herath family room', description: 'Setup extra bed, crib, kids welcome pack.', type: 'guest_service', priority: 'high', status: 'open', assignedBy: mgr2Id, assignedTo: staff1Id, room: r202, subtasks: [{ title: 'Setup extra bed', completed: false }, { title: 'Install crib', completed: false }], dueDate: new Date('2026-06-11'), createdAt: now, updatedAt: now },
    { code: 'TSK-260606-0008', property: pIds[3], title: 'Check plunge pool Room C2', description: 'Verify water level and chlorine.', type: 'maintenance', priority: 'medium', status: 'open', assignedBy: adminId, assignedTo: staff3Id, room: rc2, dueDate: now, createdAt: now, updatedAt: now },
    { code: 'TSK-260606-0009', property: pIds[0], title: 'Fix balcony door Room 201', description: 'Guest reported door lock jammed.', type: 'maintenance', priority: 'high', status: 'open', assignedBy: mgr1Id, assignedTo: staff2Id, room: r201, dueDate: new Date('2026-06-08'), createdAt: now, updatedAt: now },
  ];
  await db.collection('tasks').insertMany(tasks);
  console.log('Tasks created: 9');

  // ========== PAYMENTS ==========
  const bkDocs = await db.collection('bookings').find({}).toArray();
  const payments = [
    { property: pIds[0], booking: bkDocs.find(b => b.guest.email === 'kasun@gmail.com')._id, amount: 62700, currency: 'LKR', method: 'card', type: 'full', status: 'completed', invoiceNumber: 'INV-2026-001', gateway: { name: 'stripe', transactionId: 'pi_lk_001' }, paidAt: new Date('2026-06-01'), recordedBy: adminId, createdAt: now, updatedAt: now },
    { property: pIds[0], booking: bkDocs.find(b => b.guest.email === 'amara@gmail.com')._id, amount: 15000, currency: 'LKR', method: 'bank_transfer', type: 'advance', status: 'completed', invoiceNumber: 'INV-2026-002', paidAt: new Date('2026-06-04'), recordedBy: mgr1Id, createdAt: now, updatedAt: now },
    { property: pIds[0], booking: bkDocs.find(b => b.guest.email === 'ravi.desilva@gmail.com')._id, amount: 50000, currency: 'LKR', method: 'online', type: 'advance', status: 'completed', invoiceNumber: 'INV-2026-003', gateway: { name: 'payhere', transactionId: 'PH-10001' }, paidAt: new Date('2026-06-02'), recordedBy: mgr1Id, createdAt: now, updatedAt: now },
    { property: pIds[1], booking: bkDocs.find(b => b.guest.email === 'nimal@gmail.com')._id, amount: 35200, currency: 'LKR', method: 'cash', type: 'full', status: 'completed', invoiceNumber: 'INV-2026-004', paidAt: new Date('2026-05-20'), recordedBy: adminId, createdAt: now, updatedAt: now },
    { property: pIds[2], booking: bkDocs.find(b => b.guest.email === 'priya.nair@gmail.com')._id, amount: 37400, currency: 'LKR', method: 'card', type: 'full', status: 'completed', invoiceNumber: 'INV-2026-005', gateway: { name: 'stripe', transactionId: 'pi_lk_005' }, paidAt: new Date('2026-05-22'), recordedBy: adminId, createdAt: now, updatedAt: now },
    { property: pIds[3], booking: bkDocs.find(b => b.guest.email === 'tom.h@gmail.com')._id, amount: 143000, currency: 'LKR', method: 'card', type: 'full', status: 'completed', invoiceNumber: 'INV-2026-006', gateway: { name: 'stripe', transactionId: 'pi_lk_006' }, paidAt: new Date('2026-06-01'), recordedBy: adminId, createdAt: now, updatedAt: now },
    { property: pIds[2], booking: bkDocs.find(b => b.guest.email === 'hans.m@gmail.com')._id, amount: 25000, currency: 'LKR', method: 'card', type: 'advance', status: 'completed', invoiceNumber: 'INV-2026-007', gateway: { name: 'stripe', transactionId: 'pi_lk_007' }, paidAt: new Date('2026-06-01'), recordedBy: adminId, createdAt: now, updatedAt: now },
  ];
  await db.collection('payments').insertMany(payments);
  console.log('Payments created: 7');

  // ========== FEEDBACK ==========
  const feedback = [
    { property: pIds[0], booking: bkDocs.find(b => b.guest.email === 'kasun@gmail.com')._id, guestName: 'Kasun Wickramasinghe', guestEmail: 'kasun@gmail.com', rating: 5, title: 'Excellent beachfront stay!', comment: 'Beautiful ocean views and wonderful staff. Highly recommend!', categories: { cleanliness: 5, comfort: 5, location: 5, service: 5, value: 5 }, isPublic: true, createdAt: now, updatedAt: now },
    { property: pIds[1], booking: bkDocs.find(b => b.guest.email === 'nimal@gmail.com')._id, guestName: 'Nimal Fernando', guestEmail: 'nimal@gmail.com', rating: 4, title: 'Cozy mountain retreat', comment: 'Loved the fireplace and garden. Cool weather was perfect.', categories: { cleanliness: 4, comfort: 5, location: 5, service: 4, value: 4 }, isPublic: true, createdAt: now, updatedAt: now },
    { property: pIds[2], booking: bkDocs.find(b => b.guest.email === 'priya.nair@gmail.com')._id, guestName: 'Priya Nair', guestEmail: 'priya.nair@gmail.com', rating: 4, title: 'Unique eco experience', comment: 'Kayaking was amazing. Lodge was basic but very clean.', categories: { cleanliness: 4, comfort: 3, location: 5, service: 4, value: 4 }, isPublic: true, createdAt: now, updatedAt: now },
    { property: pIds[3], booking: bkDocs.find(b => b.guest.email === 'tom.h@gmail.com')._id, guestName: 'Tom Henderson', guestEmail: 'tom.h@gmail.com', rating: 5, title: 'Incredible jungle retreat', comment: 'Sleeping above the canopy was magical. Plunge pool was perfect!', categories: { cleanliness: 5, comfort: 5, location: 5, service: 5, value: 5 }, isPublic: true, createdAt: now, updatedAt: now },
  ];
  await db.collection('feedbacks').insertMany(feedback);
  console.log('Feedback created: 4');

  // ========== NOTIFICATIONS ==========
  const notifications = [
    { recipient: adminId, type: 'booking_confirmed', title: 'New Booking', message: 'Sanduni Perera booked Palm Family Room for Jun 20-23', channels: { inApp: true }, read: false, sent: true, sentAt: now, createdAt: now, updatedAt: now },
    { recipient: adminId, type: 'payment_received', title: 'Payment Received', message: 'LKR 62,700 received from Kasun Wickramasinghe via card', channels: { inApp: true }, read: true, readAt: now, sent: true, sentAt: now, createdAt: now, updatedAt: now },
    { recipient: mgr1Id, type: 'task_assigned', title: 'Urgent Task', message: 'Fix AC in Room 101 - guest checking in tomorrow', channels: { inApp: true }, read: false, sent: true, sentAt: now, createdAt: now, updatedAt: now },
    { recipient: staff1Id, type: 'task_assigned', title: 'New Task', message: 'Deep clean Room 102 after checkout', channels: { inApp: true }, read: true, readAt: now, sent: true, sentAt: now, createdAt: now, updatedAt: now },
    { recipient: staff1Id, type: 'task_assigned', title: 'Guest Service', message: 'Welcome package for Ravi de Silva - Anniversary', channels: { inApp: true }, read: false, sent: true, sentAt: now, createdAt: now, updatedAt: now },
  ];
  await db.collection('notifications').insertMany(notifications);
  console.log('Notifications created: 5');

  // ========== AUDIT LOGS ==========
  const auditLogs = [
    { user: adminId, action: 'register', entity: 'User', description: 'Admin registered', status: 'success', createdAt: now, updatedAt: now },
    { user: adminId, action: 'create', entity: 'Property', description: 'Created Seaside Resort & Spa', status: 'success', createdAt: now, updatedAt: now },
    { user: adminId, action: 'create', entity: 'Property', description: 'Created Mountain View Inn', status: 'success', createdAt: now, updatedAt: now },
    { user: adminId, action: 'create', entity: 'Booking', message: 'Booking for Kasun Wickramasinghe', status: 'success', createdAt: now, updatedAt: now },
    { user: mgr1Id, action: 'create', entity: 'Booking', description: 'Booking for Amara Jayawardena', status: 'success', createdAt: now, updatedAt: now },
  ];
  await db.collection('auditlogs').insertMany(auditLogs);
  console.log('Audit logs created: 5');

  console.log('\n========================================');
  console.log('SEED COMPLETE');
  console.log('========================================\n');
  console.log('CREDENTIALS (password: password123):');
  console.log('─'.repeat(50));
  console.log('Admin:    kamal@easeinn.com');
  console.log('Manager:  nadeesha@easeinn.com');
  console.log('Manager:  ashan@easeinn.com');
  console.log('Staff:    dilshan@easeinn.com');
  console.log('Staff:    kavindu@easeinn.com');
  console.log('Staff:    tharaka@easeinn.com');
  console.log('─'.repeat(50));
  console.log('Users: 6 | Properties: 4 | Rooms: 15');
  console.log('Bookings: 10 | Tasks: 9 | Payments: 7');
  console.log('Feedback: 4 | Notifications: 5 | Audit Logs: 5');

  await mongoose.disconnect();
}

seed().catch(e => { console.error(e); process.exit(1); });

import mongoose from 'mongoose'; // The database driver used to perform direct, low-level queries

// The name of the special database table that purely keeps track of numbers (like "What was the last booking number we handed out?")
const COUNTER_COLLECTION = 'counters';

// ==========================================
// 1. GET NEXT SEQUENCE (The Core Engine)
// Generates human-readable, auto-incrementing IDs like "BKG-240518-0001" instead of ugly MongoDB ObjectIDs.
// ==========================================
async function getNextSequence(name, prefix, dateBased = false) {
  const db = mongoose.connection.db; // Get raw, direct access to the MongoDB engine
  const today = new Date();
  
  // Format Date into a short string: YYMMDD (e.g., May 18, 2024 becomes "240518")
  const datePart = `${String(today.getFullYear()).slice(2)}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;

  // Decide what to name the counter. 
  // If it's date-based, we make a new counter every single day (e.g., "booking_240518").
  // This means the sequence resets to 0001 every morning.
  let counterName = name;
  if (dateBased) {
    counterName = `${name}_${datePart}`;
  }

  // ==========================================
  // 2. AUTO-RECOVERY & HEALING
  // What happens if someone accidentally deletes the 'counters' database table?
  // We don't want to start back at 0001 and accidentally overwrite old reservations!
  // ==========================================
  const collectionMap = {
    'booking': 'bookings',
    'property': 'properties',
    'room': 'rooms',
    'task': 'tasks',
    'user': 'users',
    'payment': 'payments'
  };

  let maxSeq = 0;
  const colName = collectionMap[name];
  
  // SCAN THE ENTIRE DATABASE: Look at every single existing item of this type.
  // We extract the number from the end of their code (e.g., extracting "42" from "BKG-0042").
  // We find the absolute highest number that currently exists.
  if (colName) {
    const docs = await db.collection(colName).find({}).toArray();
    for (const doc of docs) {
      if (doc.code) {
        const parts = doc.code.split('-'); // Split "BKG-0042" into ["BKG", "0042"]
        const lastPart = parts[parts.length - 1]; // Grab "0042"
        const num = parseInt(lastPart, 10); // Convert it to the math number 42
        if (!isNaN(num) && num > maxSeq) {
          maxSeq = num; // We found a new high score
        }
      }
    }
  }

  // ==========================================
  // 3. ATOMIC COUNTER UPDATE
  // ==========================================
  // Check the dedicated counter table
  const existingCounter = await db.collection(COUNTER_COLLECTION).findOne({ _id: counterName });
  
  // If the counter table is missing, OR if our database scan found a number higher than what the counter table thought was the highest...
  if (!existingCounter || existingCounter.seq < maxSeq) {
    // Force the counter table to update to match reality. This heals the database.
    await db.collection(COUNTER_COLLECTION).updateOne(
      { _id: counterName },
      { $set: { seq: maxSeq } },
      { upsert: true }
    );
  }

  // CRITICAL SECURITY: `findOneAndUpdate` with `$inc` is "Atomic". 
  // This means if 100 people try to book a room at the exact same millisecond, 
  // the database will perfectly queue them up and hand out 1, 2, 3, 4 without ever giving two people the same number.
  const result = await db.collection(COUNTER_COLLECTION).findOneAndUpdate(
    { _id: counterName },
    { $inc: { seq: 1 } },
    { returnDocument: 'after', upsert: true }
  );

  const seq = result.value ? result.value.seq : result.seq;

  // ==========================================
  // 4. FORMAT AND RETURN FINAL CODE
  // ==========================================
  // Pad the number with leading zeros (e.g., 5 becomes "0005")
  if (dateBased) {
    return `${prefix}-${datePart}-${String(seq).padStart(4, '0')}`; // Result: "BKG-240518-0005"
  }
  return `${prefix}-${String(seq).padStart(4, '0')}`; // Result: "PRP-0005"
}

// ==========================================
// EASY EXPORT FUNCTIONS
// These act as simple shortcuts so the rest of the app doesn't have to remember the prefixes
// ==========================================
export const generatePropertyCode = () => getNextSequence('property', 'PRP');
export const generateRoomCode = () => getNextSequence('room', 'RM');
export const generateBookingCode = () => getNextSequence('booking', 'BK', true); // true = Add Date
export const generateTaskCode = () => getNextSequence('task', 'TSK', true); // true = Add Date
export const generateUserCode = () => getNextSequence('user', 'EMP');
export const generatePaymentCode = () => getNextSequence('payment', 'INV', true); // true = Add Date


// ==========================================
// BACKFILL ALL CODES
// A maintenance script. If an admin imports a massive spreadsheet of old data that doesn't have human-readable IDs,
// this script loops through every single item in the entire database and generates a shiny new ID for it.
// ==========================================
export const backfillAllCodes = async () => {
  const db = mongoose.connection.db;

  // Find all hotels missing a code, sort them oldest to newest, and assign them codes
  const properties = await db.collection('properties').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const p of properties) {
    const code = await generatePropertyCode();
    await db.collection('properties').updateOne({ _id: p._id }, { $set: { code } });
  }

  // Same for rooms
  const rooms = await db.collection('rooms').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const r of rooms) {
    const code = await generateRoomCode();
    await db.collection('rooms').updateOne({ _id: r._id }, { $set: { code } });
  }

  // Same for users
  const users = await db.collection('users').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const u of users) {
    const code = await generateUserCode();
    await db.collection('users').updateOne({ _id: u._id }, { $set: { code } });
  }

  // Same for reservations
  const bookings = await db.collection('bookings').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const b of bookings) {
    const code = await generateBookingCode();
    await db.collection('bookings').updateOne({ _id: b._id }, { $set: { code } });
  }

  // Same for chores
  const tasks = await db.collection('tasks').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const t of tasks) {
    const code = await generateTaskCode();
    await db.collection('tasks').updateOne({ _id: t._id }, { $set: { code } });
  }

  // Same for invoices
  const payments = await db.collection('payments').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const p of payments) {
    const code = await generatePaymentCode();
    await db.collection('payments').updateOne({ _id: p._id }, { $set: { code } });
  }

  // Return a report to the admin showing exactly how many items were successfully fixed
  return {
    properties: properties.length,
    rooms: rooms.length,
    users: users.length,
    bookings: bookings.length,
    tasks: tasks.length,
    payments: payments.length,
  };
};

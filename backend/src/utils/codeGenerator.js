import mongoose from 'mongoose';

const COUNTER_COLLECTION = 'counters';

async function getNextSequence(name, prefix, dateBased = false) {
  const db = mongoose.connection.db;
  const today = new Date();
  const datePart = `${String(today.getFullYear()).slice(2)}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;

  let counterName = name;
  if (dateBased) {
    counterName = `${name}_${datePart}`;
  }

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
  if (colName) {
    const docs = await db.collection(colName).find({}).toArray();
    for (const doc of docs) {
      if (doc.code) {
        const parts = doc.code.split('-');
        const lastPart = parts[parts.length - 1];
        const num = parseInt(lastPart, 10);
        if (!isNaN(num) && num > maxSeq) {
          maxSeq = num;
        }
      }
    }
  }

  const existingCounter = await db.collection(COUNTER_COLLECTION).findOne({ _id: counterName });
  if (!existingCounter || existingCounter.seq < maxSeq) {
    await db.collection(COUNTER_COLLECTION).updateOne(
      { _id: counterName },
      { $set: { seq: maxSeq } },
      { upsert: true }
    );
  }

  const result = await db.collection(COUNTER_COLLECTION).findOneAndUpdate(
    { _id: counterName },
    { $inc: { seq: 1 } },
    { upsert: true, returnDocument: 'after' }
  );

  const seq = result.seq;
  const seqStr = String(seq).padStart(4, '0');

  if (dateBased) {
    return `${prefix}-${datePart}-${seqStr}`;
  }
  return `${prefix}-${seqStr}`;
}

export const generateBookingCode = () => getNextSequence('booking', 'BK', true);
export const generatePropertyCode = () => getNextSequence('property', 'PR', false);
export const generateRoomCode = () => getNextSequence('room', 'RM', false);
export const generateTaskCode = () => getNextSequence('task', 'TSK', true);
export const generateUserCode = () => getNextSequence('user', 'EMP', false);
export const generatePaymentCode = () => getNextSequence('payment', 'PAY', true);

export const backfillAllCodes = async () => {
  const db = mongoose.connection.db;

  const properties = await db.collection('properties').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const p of properties) {
    const code = await generatePropertyCode();
    await db.collection('properties').updateOne({ _id: p._id }, { $set: { code } });
  }

  const rooms = await db.collection('rooms').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const r of rooms) {
    const code = await generateRoomCode();
    await db.collection('rooms').updateOne({ _id: r._id }, { $set: { code } });
  }

  const users = await db.collection('users').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const u of users) {
    const code = await generateUserCode();
    await db.collection('users').updateOne({ _id: u._id }, { $set: { code } });
  }

  const bookings = await db.collection('bookings').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const b of bookings) {
    const code = await generateBookingCode();
    await db.collection('bookings').updateOne({ _id: b._id }, { $set: { code } });
  }

  const tasks = await db.collection('tasks').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const t of tasks) {
    const code = await generateTaskCode();
    await db.collection('tasks').updateOne({ _id: t._id }, { $set: { code } });
  }

  const payments = await db.collection('payments').find({ code: { $exists: false } }).sort({ createdAt: 1 }).toArray();
  for (const p of payments) {
    const code = await generatePaymentCode();
    await db.collection('payments').updateOne({ _id: p._id }, { $set: { code } });
  }

  return {
    properties: properties.length,
    rooms: rooms.length,
    users: users.length,
    bookings: bookings.length,
    tasks: tasks.length,
    payments: payments.length,
  };
};

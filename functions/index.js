const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
initializeApp();
const db = getFirestore();
const DAY_MS = 86400000;
function day(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    throw new HttpsError('invalid-argument', 'Use YYYY-MM-DD dates');
  }
  const ms = Date.parse(value + 'T00:00:00Z');
  if (!Number.isFinite(ms) || new Date(ms).toISOString().slice(0, 10) !== value) {
    throw new HttpsError('invalid-argument', 'Invalid date');
  }
  return ms;
}
exports.createBooking = onCall({ region: 'asia-south1' }, async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first');
  const admin = await db.collection('admins').doc(request.auth.uid).get();
  if (!admin.exists || admin.get('active') !== true) {
    throw new HttpsError('permission-denied', 'Administrator access required');
  }
  const { guestName, phone, checkInDate, checkOutDate, totalPaise } = request.data || {};
  if (typeof guestName !== 'string' || guestName.trim().length < 2 || guestName.length > 120
      || typeof phone !== 'string' || !/^\+?[0-9 ()-]{8,20}$/.test(phone)
      || !Number.isSafeInteger(totalPaise) || totalPaise <= 0 || totalPaise > 1000000000) {
    throw new HttpsError('invalid-argument', 'Invalid customer or amount');
  }
  const start = day(checkInDate), end = day(checkOutDate);
  const nights = (end - start) / DAY_MS;
  if (!Number.isInteger(nights) || nights < 1 || nights > 60) {
    throw new HttpsError('invalid-argument', 'Book 1 to 60 nights');
  }
  // A night is [check-in, check-out), so checkout day can be reused.
  const keys = Array.from({ length: nights },
    (_, i) => new Date(start + i * DAY_MS).toISOString().slice(0, 10));
  const refs = keys.map(k => db.collection('nightLocks').doc(k));
  const booking = db.collection('bookings').doc();
  await db.runTransaction(async tx => {
    const existing = await Promise.all(refs.map(ref => tx.get(ref)));
    if (existing.some(item => item.exists)) {
      throw new HttpsError('already-exists', 'A confirmed booking already occupies those nights');
    }
    tx.create(booking, {
      guestName: guestName.trim(), phone: phone.trim(), checkInDate, checkOutDate,
      totalPaise, paidPaise: 0, status: 'confirmed', source: 'admin',
      createdBy: request.auth.uid,
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    });
    refs.forEach((ref, index) => tx.create(ref, { bookingId: booking.id, date: keys[index] }));
  });
  return { bookingId: booking.id };
});

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const propertyOffset = Duration(hours: 5, minutes: 30);

/// 11 AM in Asia/Kolkata, independent of the phone's current timezone.
DateTime propertyCheckIn(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day, 5, 30);
DateTime propertyDate(DateTime instant) => instant.toUtc().add(propertyOffset);

int? parsePaise(String input) {
  final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,2}))?$').firstMatch(input.trim());
  if (match == null) return null;
  final value =
      int.parse(match[1]!) * 100 + int.parse((match[2] ?? '').padRight(2, '0'));
  return value > 0 && value <= 1000000000 ? value : null;
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

Map<String, dynamic> bookingView(String id, Map<String, dynamic> data) {
  final start = propertyDate((data['checkInAt'] as Timestamp).toDate());
  final end = propertyDate((data['checkOutAt'] as Timestamp).toDate());
  return {
    ...data,
    'id': id,
    'checkInDate': _dayKey(start),
    'checkOutDate': _dayKey(end)
  };
}

class BookingConflict implements Exception {
  @override
  String toString() =>
      'That date is already booked. Please choose another date.';
}

class BookingRepository {
  BookingRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  Stream<List<Map<String, dynamic>>> watchMonth(DateTime month) => _db
      .collection('bookings')
      .where('checkInAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(
              propertyCheckIn(DateTime(month.year, month.month))))
      .where('checkInAt',
          isLessThan: Timestamp.fromDate(
              propertyCheckIn(DateTime(month.year, month.month + 1))))
      .orderBy('checkInAt')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => bookingView(doc.id, doc.data())).toList());

  Future<String> save({
    required String guestName,
    required String phone,
    required DateTime day,
    required int totalPaise,
    String notes = '',
    String source = 'phone',
    int guestCount = 1,
    String? id,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in again.');
    final start = propertyCheckIn(day);
    final slotId = start.millisecondsSinceEpoch.toString();
    final reference = id == null
        ? _db.collection('bookings').doc()
        : _db.collection('bookings').doc(id);
    final slot = _db.collection('slots').doc(slotId);
    await _db.runTransaction((transaction) async {
      Map<String, dynamic>? previous;
      if (id != null) {
        previous = (await transaction.get(reference)).data();
        if (previous == null || previous['status'] != 'confirmed') {
          throw StateError('This booking is no longer available to edit.');
        }
      }
      final occupied = await transaction.get(slot);
      if (occupied.exists && occupied.data()?['bookingId'] != reference.id) {
        throw BookingConflict();
      }
      if (previous != null && previous['slotId'] != slotId) {
        transaction
            .delete(_db.collection('slots').doc(previous['slotId'] as String));
      }
      final now = FieldValue.serverTimestamp();
      transaction.set(reference, {
        'guestName': guestName.trim(),
        'phone': phone.trim(),
        'checkInAt': Timestamp.fromDate(start),
        'checkOutAt': Timestamp.fromDate(start.add(const Duration(hours: 24))),
        'slotId': slotId,
        'totalPaise': totalPaise,
        'paidPaise': previous?['paidPaise'] ?? 0,
        'status': 'confirmed',
        'notes': notes.trim(),
        'source': source,
        'guestCount': guestCount,
        'createdBy': previous?['createdBy'] ?? uid,
        'updatedBy': uid,
        'createdAt': previous?['createdAt'] ?? now,
        'updatedAt': now,
        'revision': ((previous?['revision'] as int?) ?? -1) + 1,
      });
      if (!occupied.exists) {
        transaction.set(slot, {
          'bookingId': reference.id,
          'checkInAt': Timestamp.fromDate(start)
        });
      }
    });
    return reference.id;
  }

  Future<void> cancel(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in again.');
    final reference = _db.collection('bookings').doc(id);
    await _db.runTransaction((transaction) async {
      final previous = (await transaction.get(reference)).data();
      if (previous == null || previous['status'] != 'confirmed') {
        throw StateError('This booking is already cancelled.');
      }
      transaction.update(reference, {
        'status': 'cancelled',
        'updatedBy': uid,
        'updatedAt': FieldValue.serverTimestamp(),
        'revision': (previous['revision'] as int) + 1,
      });
      transaction
          .delete(_db.collection('slots').doc(previous['slotId'] as String));
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booking_domain.dart';
export 'booking_domain.dart';

class BookingRepository implements BookingStore {
  BookingRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  Booking _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return Booking(
        id: doc.id,
        guestName: d['guestName'] as String,
        phone: d['phone'] as String,
        checkInAt: (d['checkInAt'] as Timestamp).toDate().toUtc(),
        checkOutAt: (d['checkOutAt'] as Timestamp).toDate().toUtc(),
        totalPaise: d['totalPaise'] as int,
        paidPaise: d['paidPaise'] as int? ?? 0,
        guestCount: d['guestCount'] as int? ?? 2,
        status: d['status'] as String,
        notes: d['notes'] as String? ?? '',
        source: d['source'] as String? ?? 'phone',
        revision: d['revision'] as int? ?? 0,
        bookingCode: d['bookingCode'] as String? ?? '');
  }

  @override
  Stream<List<Booking>> watchMonth(DateTime month) => _db
      .collection('bookings')
      .where('checkInAt',
          isLessThan: Timestamp.fromDate(
              propertyCheckIn(DateTime(month.year, month.month + 1))))
      .where('checkOutAt',
          isGreaterThan: Timestamp.fromDate(
              propertyCheckIn(DateTime(month.year, month.month))))
      .orderBy('checkInAt')
      .snapshots()
      .map((s) => s.docs.map(_fromDoc).toList());
  @override
  Stream<Booking?> watchBooking(String id) => _db
      .collection('bookings')
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? _fromDoc(d) : null);
  @override
  Stream<Map<String, String>> watchOccupiedSlots() =>
      _db.collection('availability').doc('state').snapshots().map((d) {
        if (!d.exists) throw StateError('Availability is not ready.');
        return Map<String, String>.from(d.data()!['slots'] as Map);
      });
  @override
  Future<List<AmountSuggestion>> suggestedAmounts() async {
    final recent = await _db
        .collection('bookings')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    return amountSuggestions(recent.docs
        .where((d) => d.data()['status'] == 'confirmed')
        .map((d) => d.data()['totalPaise'] as int));
  }

  @override
  Future<String> save(
      {required String guestName,
      required String phone,
      required DateTime day,
      required DateTime checkout,
      required int totalPaise,
      required int guestCount,
      int paidPaise = 0,
      String notes = '',
      String source = 'phone',
      String? id,
      int? expectedRevision}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in again.');
    if (guestCount < 2 || guestCount > 100) {
      throw ArgumentError('Choose between 2 and 100 guests.');
    }
    if (totalPaise <= 0 || paidPaise < 0 || paidPaise > totalPaise) {
      throw ArgumentError(
          'Paid amount must be between zero and the booking amount.');
    }
    final start = propertyCheckIn(day), end = propertyCheckIn(checkout);
    final keys = occupiedSlotKeys(start, end);
    var reference = _db.collection('bookings').doc(id);
    final dateCode = bookingDateCode(propertyDay(DateTime.now()));
    final availability = _db.collection('availability').doc('state');
    final mutationId = _db.collection('bookings').doc().id;
    int? observedRevision;
    for (var attempt = 0;; attempt++) {
      try {
        await _db.runTransaction((tx) async {
          final previousDoc = id == null ? null : await tx.get(reference);
          final previous = previousDoc?.data();
          if (id != null &&
              (previous == null || previous['status'] != 'confirmed')) {
            throw StateError('This booking is no longer available to edit.');
          }
          if (previous != null &&
              expectedRevision != null &&
              previous['revision'] != expectedRevision) {
            throw StateError(
                'This booking changed on another device. Reopen it before editing.');
          }
          final sameDates = previous != null &&
              (previous['checkInAt'] as Timestamp).toDate().toUtc() == start &&
              (previous['checkOutAt'] as Timestamp).toDate().toUtc() == end;
          if (!canBookDay(day) && !sameDates) {
            throw ArgumentError('Past dates cannot be booked.');
          }
          final state = (await tx.get(availability)).data();
          if (state == null) {
            throw StateError(
                'Booking availability is being updated. Please try again shortly.');
          }
          observedRevision = state['revision'] as int;
          final sequence = state['sequenceDate'] == dateCode
              ? (state['sequenceNumber'] as int? ?? 0) + 1
              : 1;
          if (id == null && sequence > 9999) {
            throw StateError('Daily booking limit reached.');
          }
          final code = id == null
              ? readableBookingCode(dateCode, sequence)
              : previous?['bookingCode'] as String?;
          if (id == null) {
            reference = _db
                .collection('bookings')
                .doc(bookingDocumentName(guestName, code!));
          }
          final slots = Map<String, dynamic>.from(state['slots'] as Map);
          for (final key in keys) {
            if (slots[key] != null && slots[key] != reference.id) {
              throw BookingConflict();
            }
          }
          if (previous != null) {
            for (final key in occupiedSlotKeys(
                (previous['checkInAt'] as Timestamp).toDate(),
                (previous['checkOutAt'] as Timestamp).toDate())) {
              if (slots[key] != reference.id) {
                throw StateError(
                    'Availability needs review. Please contact the property owner.');
              }
              slots.remove(key);
            }
          }
          for (final key in keys) {
            slots[key] = reference.id;
          }
          final now = FieldValue.serverTimestamp();
          tx.set(reference, {
            'guestName': guestName.trim(),
            'phone': phone.trim(),
            'checkInAt': Timestamp.fromDate(start),
            'checkOutAt': Timestamp.fromDate(end),
            'slotId': keys.first,
            'slotIds': keys,
            'totalPaise': totalPaise,
            'paidPaise': paidPaise,
            if (code != null) 'bookingCode': code,
            'status': 'confirmed',
            'guestCount': guestCount,
            'notes': notes.trim(),
            'source': source,
            'createdBy': previous?['createdBy'] ?? uid,
            'updatedBy': uid,
            'createdAt': previous?['createdAt'] ?? now,
            'updatedAt': now,
            'revision': ((previous?['revision'] as int?) ?? -1) + 1,
            'mutationId': mutationId,
          });
          tx.set(availability, {
            ...state,
            'slots': slots,
            'revision': (state['revision'] as int) + 1,
            'lastBookingId': reference.id,
            if (id == null) 'sequenceDate': dateCode,
            if (id == null) 'sequenceNumber': sequence,
            'mutationId': mutationId,
            'updatedAt': now
          });
        });
        break;
      } catch (e) {
        final racing = e is BookingNumberConflict ||
            e is FirebaseException && e.code == 'permission-denied';
        if (!racing || attempt >= 3 || observedRevision == null) rethrow;
        final latest =
            (await availability.get(const GetOptions(source: Source.server)))
                .data();
        if (latest?['revision'] == observedRevision) rethrow;
      }
    }
    return reference.id;
  }

  @override
  Future<void> cancel(String id) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in again.');
    final reference = _db.collection('bookings').doc(id),
        availability = _db.collection('availability').doc('state');
    final mutationId = _db.collection('bookings').doc().id;
    await _db.runTransaction((tx) async {
      final previous = (await tx.get(reference)).data();
      final state = (await tx.get(availability)).data();
      if (previous == null || previous['status'] != 'confirmed') {
        throw StateError('This booking is already cancelled.');
      }
      if (state == null) throw StateError('Booking availability is not ready.');
      final slots = Map<String, dynamic>.from(state['slots'] as Map);
      for (final key in occupiedSlotKeys(
          (previous['checkInAt'] as Timestamp).toDate(),
          (previous['checkOutAt'] as Timestamp).toDate())) {
        if (slots[key] != id) throw StateError('Availability needs review.');
        slots.remove(key);
      }
      final now = FieldValue.serverTimestamp();
      tx.update(reference, {
        'slotIds': occupiedSlotKeys(
            (previous['checkInAt'] as Timestamp).toDate(),
            (previous['checkOutAt'] as Timestamp).toDate()),
        'status': 'cancelled',
        'updatedBy': uid,
        'updatedAt': now,
        'revision': (previous['revision'] as int) + 1,
        'mutationId': mutationId
      });
      tx.set(availability, {
        ...state,
        'slots': slots,
        'revision': (state['revision'] as int) + 1,
        'lastBookingId': id,
        'mutationId': mutationId,
        'updatedAt': now
      });
    });
  }
}

class BookingNumberConflict implements Exception {
  const BookingNumberConflict();
}

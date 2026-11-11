const propertyOffset = Duration(hours: 5, minutes: 30);
const maxStayNights = 31;

DateTime propertyDate(DateTime instant) => instant.toUtc().add(propertyOffset);
DateTime propertyDay(DateTime instant) {
  final date = propertyDate(instant);
  return DateTime(date.year, date.month, date.day);
}

DateTime propertyCheckIn(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day, 5, 30);
DateTime calendarDay(DateTime day) => DateTime(day.year, day.month, day.day);
bool canBookDay(DateTime day, {DateTime? now}) =>
    !calendarDay(day).isBefore(propertyDay(now ?? DateTime.now()));
int stayNights(DateTime start, DateTime end) =>
    propertyCheckIn(end).difference(propertyCheckIn(start)).inDays;

int? parsePaise(String input) {
  final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,2}))?$').firstMatch(input.trim());
  if (match == null) return null;
  final value =
      int.parse(match[1]!) * 100 + int.parse((match[2] ?? '').padRight(2, '0'));
  return value > 0 && value <= 1000000000 ? value : null;
}

List<String> occupiedSlotKeys(DateTime start, DateTime end) {
  final nights = end.toUtc().difference(start.toUtc()).inDays;
  if (nights < 1 || nights > maxStayNights) {
    throw ArgumentError('Choose a stay of 1 to $maxStayNights nights.');
  }
  return List.generate(
      nights,
      (i) => start
          .toUtc()
          .add(Duration(days: i))
          .millisecondsSinceEpoch
          .toString());
}

class Booking {
  const Booking(
      {required this.id,
      required this.guestName,
      required this.phone,
      required this.checkInAt,
      required this.checkOutAt,
      required this.totalPaise,
      required this.guestCount,
      this.paidPaise = 0,
      this.status = 'confirmed',
      this.source = 'phone',
      this.notes = '',
      this.revision = 0});
  final String id, guestName, phone, status, source, notes;
  final DateTime checkInAt, checkOutAt;
  final int totalPaise, paidPaise, guestCount, revision;
  DateTime get arrival => propertyDay(checkInAt);
  DateTime get departure => propertyDay(checkOutAt);
  int get nights => checkOutAt.difference(checkInAt).inDays;
  String statusLabel({DateTime? now}) {
    final instant = (now ?? DateTime.now()).toUtc();
    if (status == 'cancelled') return 'Cancelled';
    if (!checkOutAt.isAfter(instant)) return 'Completed';
    if (!checkInAt.isAfter(instant)) return 'Checked in';
    return 'Confirmed';
  }

  bool occupies(DateTime day) {
    final slot = propertyCheckIn(day);
    return status == 'confirmed' &&
        !slot.isBefore(checkInAt) &&
        slot.isBefore(checkOutAt);
  }
}

class AmountSuggestion {
  const AmountSuggestion(this.paise, this.count);
  final int paise, count;
}

List<AmountSuggestion> amountSuggestions(Iterable<int> history) {
  final counts = <int, int>{};
  for (final value in history) {
    final round = ((value + 50000) ~/ 100000) * 100000;
    if (round >= 800000 && round <= 2500000) {
      counts[round] = (counts[round] ?? 0) + 1;
    }
  }
  final choices = {
    ...counts.keys,
    800000,
    1000000,
    1200000,
    1500000,
    1800000,
    2000000,
    2500000
  }.toList();
  choices.sort((a, b) {
    final popularity = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
    return popularity == 0 ? a.compareTo(b) : popularity;
  });
  return choices
      .take(7)
      .map((value) => AmountSuggestion(value, counts[value] ?? 0))
      .toList();
}

abstract class BookingStore {
  Stream<List<Booking>> watchMonth(DateTime month);
  Stream<Booking?> watchBooking(String id);
  Future<List<AmountSuggestion>> suggestedAmounts();
  Future<String> save(
      {required String guestName,
      required String phone,
      required DateTime day,
      required DateTime checkout,
      required int totalPaise,
      required int guestCount,
      String notes = '',
      String source = 'phone',
      String? id,
      int? expectedRevision});
  Future<void> cancel(String id);
}

class BookingConflict implements Exception {
  @override
  String toString() =>
      'One or more selected dates are already booked. Please choose another stay.';
}

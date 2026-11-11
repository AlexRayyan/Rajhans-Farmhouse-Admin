import 'package:flutter_test/flutter_test.dart';
import 'package:rajhans_farmhouse_admin/src/booking_repository.dart';

void main() {
  test('amounts preserve paise and reject ambiguous numeric formats', () {
    expect(parsePaise('15000.25'), 1500025);
    expect(parsePaise('0.01'), 1);
    expect(parsePaise(' 120.5 '), 12050);
    for (final value in [
      '0',
      '-10',
      'NaN',
      'Infinity',
      '1e3',
      '1.005',
      '10000001'
    ]) {
      expect(parsePaise(value), isNull, reason: value);
    }
  });
  test('11 AM property time has a stable UTC instant', () {
    final start = propertyCheckIn(DateTime(2028, 2, 29));
    expect(start, DateTime.utc(2028, 2, 29, 5, 30));
    final checkout = start.add(const Duration(hours: 24));
    expect(propertyDate(checkout).day, 1);
    expect(propertyDate(checkout).month, 3);
    expect(propertyDate(checkout).hour, 11);
    expect(propertyCheckIn(DateTime(2028, 3, 1)), checkout);
  });
}

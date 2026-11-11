import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'booking_domain.dart';

class NativeServices {
  static const channel = MethodChannel('com.rajhansfarmhouse.admin/device');
  static Future<ThemeMode> loadTheme() async {
    try {
      final value = await channel.invokeMethod<String>('getTheme');
      return ThemeMode.values.firstWhere((mode) => mode.name == value,
          orElse: () => ThemeMode.dark);
    } on PlatformException {
      return ThemeMode.dark;
    } on MissingPluginException {
      return ThemeMode.dark;
    }
  }

  static Future<void> saveTheme(ThemeMode mode) =>
      channel.invokeMethod<void>('setTheme', {'value': mode.name});
  static Future<List<Map<String, dynamic>>> recentCalls() async {
    final data = await channel.invokeListMethod<dynamic>('recentCalls');
    return (data ?? [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  static Future<bool> callLogAllowed() async =>
      await channel.invokeMethod<bool>('callLogAllowed') ?? false;

  static Future<Map<String, dynamic>?> pickContact() async {
    final result =
        await channel.invokeMapMethod<String, dynamic>('pickContact');
    return result == null ? null : Map<String, dynamic>.from(result);
  }

  static Future<void> receipt(Booking booking, {String action = 'view'}) async {
    await channel.invokeMethod<void>('receipt', {
      'id': booking.displayId,
      'guestName': booking.guestName,
      'phone': booking.phone,
      'guestCount': booking.guestCount,
      'status': booking.statusLabel(),
      'checkIn':
          DateFormat('EEEE, dd-MMM-yyyy', 'en_US').format(booking.arrival),
      'checkOut':
          DateFormat('EEEE, dd-MMM-yyyy', 'en_US').format(booking.departure),
      'nights': booking.nights,
      'totalPaise': booking.totalPaise,
      'paidPaise': booking.paidPaise,
      'notes': booking.notes,
      'action': action,
    });
  }
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rajhans_farmhouse_admin/src/add_booking.dart';
import 'package:rajhans_farmhouse_admin/src/booking_domain.dart';
import 'package:rajhans_farmhouse_admin/src/calendar_screen.dart';
import 'package:rajhans_farmhouse_admin/src/native_services.dart';
import 'package:rajhans_farmhouse_admin/src/ui.dart';

class FakeStore implements BookingStore {
  Map<String, Object?>? saved;
  @override
  Stream<List<Booking>> watchMonth(DateTime month) => Stream.value([]);
  @override
  Stream<Booking?> watchBooking(String id) => Stream.value(null);
  @override
  Future<List<AmountSuggestion>> suggestedAmounts() async =>
      amountSuggestions([1500000, 1500000, 1000000]);
  @override
  Future<void> cancel(String id) async {}
  @override
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
      int? expectedRevision}) async {
    saved = {
      'guestName': guestName,
      'phone': phone,
      'day': day,
      'checkout': checkout,
      'totalPaise': totalPaise,
      'guestCount': guestCount
    };
    return 'test-booking';
  }
}

Widget shell(Widget child) =>
    MaterialApp(theme: farmhouseTheme(Brightness.dark), home: child);
Future<void> capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['RAJHANS_CAPTURE_DIR'];
  if (directory == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(directory).create(recursive: true);
    await File('$directory/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final futureYear = propertyDay(DateTime.now()).year + 1;
  setUpAll(() async {
    final fonts = Platform.environment['RAJHANS_FONT_DIR'];
    if (fonts != null) {
      final loader = FontLoader('Roboto');
      for (final name in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
        loader.addFont(File('$fonts/$name')
            .readAsBytes()
            .then((bytes) => ByteData.sublistView(bytes)));
      }
      await loader.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(File('$fonts/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)));
      await icons.load();
    }
  });
  test('past dates use the property timezone, including midnight in India', () {
    final now = DateTime.utc(2026, 11, 10, 20); // 11 Nov, 1:30 AM IST
    expect(canBookDay(DateTime(2026, 11, 10), now: now), isFalse);
    expect(canBookDay(DateTime(2026, 11, 11), now: now), isTrue);
    expect(
        occupiedSlotKeys(DateTime.utc(2028, 2, 28, 5, 30),
                DateTime.utc(2028, 3, 2, 5, 30))
            .length,
        3);
  });
  test('popular amount chips rank saved prices and remain round figures', () {
    final choices = amountSuggestions([1500000, 1500000, 1000000, 1499900]);
    expect(choices.first.paise, 1500000);
    expect(choices.first.count, 3);
    expect(
        choices.every((v) =>
            v.paise % 100000 == 0 && v.paise >= 800000 && v.paise <= 2500000),
        isTrue);
    expect(amountSuggestions([]).map((v) => v.paise),
        containsAll([800000, 1000000, 2500000]));
  });
  test('theme selection is written and restored through device preferences',
      () async {
    String? stored;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeServices.channel, (call) async {
      if (call.method == 'setTheme') {
        stored = (call.arguments as Map)['value'] as String;
        return null;
      }
      if (call.method == 'getTheme') return stored;
      return null;
    });
    expect(await NativeServices.loadTheme(), ThemeMode.dark);
    await NativeServices.saveTheme(ThemeMode.light);
    expect(await NativeServices.loadTheme(), ThemeMode.light);
    await NativeServices.saveTheme(ThemeMode.system);
    expect(await NativeServices.loadTheme(), ThemeMode.system);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeServices.channel, null);
  });
  testWidgets(
      'guest wheel can select 100 and save a multi-day booking with a quick amount',
      (tester) async {
    final store = FakeStore();
    await tester.pumpWidget(shell(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => AddBooking(
                            initialDate: DateTime(futureYear, 8, 24),
                            store: store))),
                child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('guest-name')), 'Test Guest');
    await tester.enterText(
        find.byKey(const ValueKey('phone')), '+919876543210');
    await tester.ensureVisible(find.text('Check-out'));
    await tester.tap(find.text('Check-out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('27'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('guest-count')));
    await tester.tap(find.byKey(const ValueKey('guest-count')));
    await tester.pumpAndSettle();
    final picker = tester
        .widget<CupertinoPicker>(find.byKey(const ValueKey('guest-wheel')));
    picker.scrollController!.jumpToItem(98);
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('100 guests'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('amount-1500000')));
    await tester.tap(find.byKey(const ValueKey('amount-1500000')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('save-booking')));
    await tester.tap(find.byKey(const ValueKey('save-booking')));
    await tester.pumpAndSettle();
    expect(store.saved?['guestCount'], 100);
    expect(store.saved?['totalPaise'], 1500000);
    expect(store.saved?['day'], DateTime(futureYear, 8, 24));
    expect(store.saved?['checkout'], DateTime(futureYear, 8, 27));
    expect(find.text('Open'), findsOneWidget);
  });
  testWidgets(
      'editable multi-day dates are readable and small-screen form renders',
      (tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final booking = Booking(
        id: 'test',
        guestName: 'Ayesha Khan',
        phone: '+919876543210',
        checkInAt: DateTime.utc(futureYear, 8, 24, 5, 30),
        checkOutAt: DateTime.utc(futureYear, 8, 27, 5, 30),
        totalPaise: 1500000,
        guestCount: 12);
    await tester.pumpWidget(shell(RepaintBoundary(
        key: const ValueKey('capture'),
        child: AddBooking(booking: booking, store: FakeStore()))));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.text(readableDate(DateTime(futureYear, 8, 24))));
    expect(
        find.text(readableDate(DateTime(futureYear, 8, 27))), findsOneWidget);
    expect(find.textContaining('3 nights'), findsOneWidget);
    await capture(tester, 'booking-form');
  });
  testWidgets(
      'calendar renders only selected-month dates and blocks past booking action',
      (tester) async {
    tester.view.physicalSize = const Size(400, 880);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shell(RepaintBoundary(
        key: const ValueKey('capture'),
        child: Scaffold(
            body: BookingCalendar(
                month: DateTime(2028, 2),
                bookings: const [],
                onMonthChanged: (_) {},
                onAdd: (_) {},
                onDetails: (_) {})))));
    await tester.pumpAndSettle();
    expect(find.text('30'), findsNothing);
    expect(find.text('31'), findsNothing);
    expect(find.byKey(const ValueKey('calendar-day-29')), findsOneWidget);
    await capture(tester, 'calendar');
    await tester.pumpWidget(shell(Scaffold(
        body: BookingCalendar(
            month: DateTime(2020, 2),
            bookings: const [],
            onMonthChanged: (_) {},
            onAdd: (_) {},
            onDetails: (_) {}))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add booking'));
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add booking'));
    expect(button.onPressed, isNull);
  });
}

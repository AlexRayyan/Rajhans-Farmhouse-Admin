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
import 'package:rajhans_farmhouse_admin/src/reports_screen.dart';
import 'package:rajhans_farmhouse_admin/src/booking_details.dart';

class FakeStore implements BookingStore {
  FakeStore({this.slots = const {}});
  final Map<String, String> slots;
  Map<String, Object?>? saved;
  @override
  Stream<List<Booking>> watchMonth(DateTime month) => Stream.value([]);
  @override
  Stream<Booking?> watchBooking(String id) => Stream.value(null);
  @override
  Stream<Map<String, String>> watchOccupiedSlots() => Stream.value(slots);
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
      int paidPaise = 0,
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
      'guestCount': guestCount,
      'paidPaise': paidPaise
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
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('amount-1500000')), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('amount-1500000')));
    await tester.pump();
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('save-booking')), 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('save-booking')));
    await tester.pumpAndSettle();
    expect(store.saved?['guestCount'], 100);
    expect(store.saved?['totalPaise'], 1500000);
    expect(store.saved?['day'], DateTime(futureYear, 8, 24));
    expect(store.saved?['checkout'], DateTime(futureYear, 8, 27));
    expect(find.text('Booking Details'), findsOneWidget);
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
    await tester.ensureVisible(find.byType(StayDateTile).first);
    final dates = tester
        .widgetList<StayDateTile>(find.byType(StayDateTile))
        .map((tile) => tile.date)
        .toList();
    expect(dates, [DateTime(futureYear, 8, 24), DateTime(futureYear, 8, 27)]);
    expect(find.text('$futureYear · 11:00 AM'), findsNWidgets(2));
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
  test('readable codes, safe document names and cross-month report totals', () {
    expect(readableBookingCode('121126', 1), 'RF121126');
    expect(readableBookingCode('121126', 2), 'RF121126-02');
    expect(bookingDocumentName('Ayesha / Khan', 'RF121126'),
        'Ayesha - Khan - RF121126');
    expect(readableDate(DateTime(2026, 11, 29)), 'Sunday, 29-Nov-2026');
    Booking sample(String id, DateTime start, DateTime end, int total, int paid,
            {String status = 'confirmed'}) =>
        Booking(
            id: id,
            guestName: 'Sample Guest',
            phone: '+919876543210',
            checkInAt: start,
            checkOutAt: end,
            totalPaise: total,
            paidPaise: paid,
            guestCount: 2,
            status: status);
    final report = BookingReport(DateTime(2027, 2), [
      sample('carry', DateTime.utc(2027, 1, 30, 5, 30),
          DateTime.utc(2027, 2, 3, 5, 30), 1200000, 500000),
      sample('new', DateTime.utc(2027, 2, 5, 5, 30),
          DateTime.utc(2027, 2, 8, 5, 30), 1800000, 600000),
      sample('cancel', DateTime.utc(2027, 2, 10, 5, 30),
          DateTime.utc(2027, 2, 12, 5, 30), 800000, 0,
          status: 'cancelled'),
    ]);
    expect(report.occupiedNights, 5);
    expect(report.total, 1800000);
    expect(report.paid, 600000);
    expect(report.outstanding, 1200000);
    expect(report.cancellations, 1);
  });
  testWidgets(
      'picker disables booked nights and checkout across an occupied stay',
      (tester) async {
    final date = DateTime(futureYear, 8, 26),
        slots = {
          propertyCheckIn(date).millisecondsSinceEpoch.toString(): 'other'
        };
    await tester.pumpWidget(shell(AddBooking(
        initialDate: DateTime(futureYear, 8, 24),
        store: FakeStore(slots: slots))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check-in'));
    await tester.pumpAndSettle();
    final incoming =
        tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(incoming.selectableDayPredicate!(date), isFalse);
    expect(
        incoming.selectableDayPredicate!(DateTime(futureYear, 8, 27)), isTrue);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check-out'));
    await tester.pumpAndSettle();
    final outgoing =
        tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
    expect(outgoing.selectableDayPredicate!(date), isTrue);
    expect(
        outgoing.selectableDayPredicate!(DateTime(futureYear, 8, 27)), isFalse);
  });
  testWidgets(
      'advance and fully-paid choices update balance and save opens details',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = FakeStore();
    await tester.pumpWidget(MaterialApp(
        theme: farmhouseTheme(Brightness.light),
        home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: AddBooking(
                initialDate: DateTime(futureYear, 11, 29), store: store))));
    await tester.pumpAndSettle();
    expect(find.text('Rajhans Farmhouse'), findsNothing);
    expect(tester.getTopLeft(find.text('Check-in')).dy,
        closeTo(tester.getTopLeft(find.text('Check-out')).dy, 1));
    await tester.enterText(
        find.byKey(const ValueKey('guest-name')), 'Ayesha Khan');
    await tester.enterText(
        find.byKey(const ValueKey('phone')), '+919876543210');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('amount')), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(const ValueKey('amount')), '20000');
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('advance-amount')), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(
        find.byKey(const ValueKey('advance-amount')), '5000');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Remaining balance'), 120,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(money(1500000)), findsWidgets);
    await tester.ensureVisible(find.byKey(const ValueKey('full-mode')));
    await tester.tap(find.byKey(const ValueKey('full-mode')));
    await tester.pumpAndSettle();
    expect(find.text(money(0)), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('save-booking')), 220,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('save-booking')));
    await tester.pumpAndSettle();
    expect(store.saved?['paidPaise'], 2000000);
    expect(find.text('Booking Details'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Check-in')).dy,
        closeTo(tester.getTopLeft(find.text('Check-out')).dy, 1));
  });
  testWidgets(
      'reports have occupancy, payments and source insights with sample data',
      (tester) async {
    tester.view.physicalSize = const Size(400, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sample = Booking(
        id: 'Ayesha Khan - RF121126',
        bookingCode: 'RF121126',
        guestName: 'Ayesha Khan',
        phone: '+919876543210',
        checkInAt: DateTime.utc(futureYear, 11, 20, 5, 30),
        checkOutAt: DateTime.utc(futureYear, 11, 23, 5, 30),
        totalPaise: 2000000,
        paidPaise: 500000,
        guestCount: 12);
    await tester.pumpWidget(shell(RepaintBoundary(
        key: const ValueKey('capture'),
        child: Scaffold(
            body: ReportsScreen(
                month: DateTime(futureYear, 11),
                bookings: [sample],
                onMonthChanged: (_) {})))));
    await tester.pumpAndSettle();
    expect(find.text('Monthly performance'), findsOneWidget);
    expect(find.text('Weekly occupied nights'), findsOneWidget);
    await capture(tester, 'reports');
    await tester.pumpWidget(MaterialApp(
        theme: farmhouseTheme(Brightness.light),
        home: RepaintBoundary(
            key: const ValueKey('capture'),
            child: BookingDetails(booking: sample, store: FakeStore()))));
    await tester.pumpAndSettle();
    await capture(tester, 'booking-details');
  });
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'booking_repository.dart';
import 'add_booking.dart';
import 'booking_details.dart';
import 'calendar_screen.dart';
import 'ui.dart';

class AdminHome extends StatefulWidget {
  const AdminHome(
      {super.key,
      required this.themeMode,
      required this.onThemeChanged,
      this.store});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final BookingStore? store;
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  late final BookingStore store = widget.store ?? BookingRepository();
  late DateTime month = DateTime(
      propertyDay(DateTime.now()).year, propertyDay(DateTime.now()).month);
  late Stream<List<Booking>> updates = store.watchMonth(month);
  int tab = 0;
  String query = '', filter = 'All';
  void setMonth(DateTime value) {
    if (month == value) return;
    setState(() {
      month = value;
      updates = store.watchMonth(value);
    });
  }

  void add([DateTime? day]) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => AddBooking(initialDate: day, store: store)));
  void details(Booking booking) => Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => BookingDetails(booking: booking, store: store)));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text([
            'Rajhans Farmhouse',
            'Calendar',
            'Bookings',
            'Reports',
            'Settings'
          ][tab]),
          actions: [
            IconButton(
                tooltip: 'Add booking',
                onPressed: add,
                icon: const Icon(Icons.add_circle_outline, color: violet))
          ]),
      bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
            NavigationDestination(
                icon: Icon(Icons.book_outlined), label: 'Bookings'),
            NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined), label: 'Settings')
          ]),
      body: tab == 4
          ? _settings()
          : StreamBuilder<List<Booking>>(
              stream: updates,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.cloud_off_outlined,
                                size: 42, color: amber),
                            const SizedBox(height: 14),
                            const Text(
                                'Unable to load bookings. Check your connection.'),
                            TextButton(
                                onPressed: () => setState(
                                    () => updates = store.watchMonth(month)),
                                child: const Text('Try again'))
                          ])));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final bookings = snapshot.data!;
                if (tab == 1) {
                  return BookingCalendar(
                      month: month,
                      bookings: bookings,
                      onMonthChanged: setMonth,
                      onAdd: add,
                      onDetails: details);
                }
                if (tab == 2) return _list(bookings);
                return _dashboard(bookings, report: tab == 3);
              }));
  Widget _settings() => ListView(padding: const EdgeInsets.all(20), children: [
        Panel(
            child: Row(children: [
          const CircleAvatar(
              backgroundColor: violet,
              child: Icon(Icons.villa_outlined, color: Colors.white)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Rajhans Farmhouse',
                    style: Theme.of(context).textTheme.titleMedium),
                const Text('Admin')
              ]))
        ])),
        const SizedBox(height: 24),
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('System')),
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark'))
        ], selected: {
          widget.themeMode
        }, onSelectionChanged: (s) => widget.onThemeChanged(s.single)),
        const SizedBox(height: 12),
        const Text('Your choice is saved on this phone.'),
        const SizedBox(height: 28),
        const Panel(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Stay timings', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('11 AM check-in · 11 AM check-out\nAsia/Kolkata · INR')
        ])),
        const SizedBox(height: 28),
        OutlinedButton.icon(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'))
      ]);
  Widget _dashboard(List<Booking> bookings, {bool report = false}) {
    final counted = bookings
        .where((b) =>
            b.status == 'confirmed' &&
            b.arrival.year == month.year &&
            b.arrival.month == month.month)
        .toList();
    final total = counted.fold<int>(0, (sum, b) => sum + b.totalPaise);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final occupied =
        List.generate(days, (i) => DateTime(month.year, month.month, i + 1))
            .where((day) => bookings.any((b) => b.occupies(day)))
            .length;
    final upcoming = bookings
        .where((b) =>
            b.status == 'confirmed' &&
            b.checkOutAt.isAfter(DateTime.now().toUtc()))
        .toList();
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          MonthControl(month: month, onChanged: setMonth),
          const SizedBox(height: 16),
          if (!report) ...[
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Icon(Icons.villa_outlined, color: violet, size: 36),
                  const SizedBox(height: 14),
                  Text('Welcome back',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  const Text('Your farmhouse stays, all in one place.')
                ])),
            const SizedBox(height: 18)
          ],
          LayoutBuilder(
              builder: (context, size) =>
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    _Metric('Bookings', '${counted.length}',
                        Icons.calendar_month_outlined, violet, size.maxWidth),
                    _Metric('Booking value', money(total), Icons.currency_rupee,
                        green, size.maxWidth),
                    _Metric(
                        'Occupancy',
                        '${(occupied / days * 100).round()}%',
                        Icons.nights_stay_outlined,
                        const Color(0xFF65ABFF),
                        size.maxWidth),
                    _Metric(
                        'Guests',
                        '${counted.fold<int>(0, (sum, b) => sum + b.guestCount)}',
                        Icons.groups_outlined,
                        amber,
                        size.maxWidth),
                  ])),
          const SizedBox(height: 20),
          if (!report)
            FilledButton.icon(
                onPressed: add,
                icon: const Icon(Icons.add),
                label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Add booking'))),
          const SizedBox(height: 24),
          Text(report ? 'Monthly bookings' : 'Upcoming stays',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if ((report ? counted : upcoming).isEmpty)
            const Panel(child: Text('No bookings to show for this month.')),
          ...(report ? counted : upcoming)
              .map((b) => BookingCard(b, onTap: () => details(b))),
          if (report) ...[
            const SizedBox(height: 16),
            const Text(
                'Booking value is the agreed total for stays checking in this month. It is not cash collected.',
                style: TextStyle(fontSize: 12))
          ],
        ]);
  }

  Widget _list(List<Booking> bookings) {
    final needle = query.toLowerCase();
    final filtered = bookings
        .where((b) =>
            (filter == 'All' || b.statusLabel() == filter) &&
            '${b.guestName} ${b.phone} ${b.id}'.toLowerCase().contains(needle))
        .toList();
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          MonthControl(month: month, onChanged: setMonth),
          const SizedBox(height: 12),
          TextField(
              onChanged: (value) => setState(() => query = value),
              decoration: const InputDecoration(
                  hintText: 'Search name, phone or booking ID',
                  prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 12),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                  children: [
                'All',
                'Confirmed',
                'Checked in',
                'Completed',
                'Cancelled'
              ]
                      .map((value) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                              label: Text(value),
                              selected: filter == value,
                              onSelected: (_) =>
                                  setState(() => filter = value))))
                      .toList())),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const Panel(child: Text('No matching bookings.')),
          ...filtered.map((b) => BookingCard(b, onTap: () => details(b))),
        ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, this.color, this.width);
  final String label, value;
  final IconData icon;
  final Color color;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: width < 320 ? width : (width - 12) / 2,
      child: Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(height: 16),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall)
      ])));
}

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'booking_repository.dart';

String dateKey(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
String money(int paise) => NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: paise % 100 == 0 ? 0 : 2)
    .format(paise / 100);

class AdminHome extends StatefulWidget {
  const AdminHome(
      {super.key, required this.themeMode, required this.onThemeChanged});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int tab = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  late Stream<List<Map<String, dynamic>>> bookingsStream;
  final repository = BookingRepository();
  @override
  void initState() {
    super.initState();
    bookingsStream = repository.watchMonth(month);
  }

  void changeMonth(DateTime value) => setState(() {
        month = value;
        bookingsStream = repository.watchMonth(value);
      });
  @override
  Widget build(BuildContext context) {
    final names = ['Home', 'Calendar', 'Bookings', 'Reports', 'Settings'];
    return Scaffold(
      appBar: AppBar(
          title: Text(tab == 0 ? 'Rajhans Farmhouse' : names[tab]),
          actions: [
            IconButton(
                tooltip: 'Add booking',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const AddBooking())),
                icon: const Icon(Icons.add_circle_outline)),
          ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
          NavigationDestination(
              icon: Icon(Icons.book_outlined), label: 'Bookings'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
      body: tab == 4
          ? ListView(children: [
              ListTile(
                  title: const Text('Appearance'),
                  subtitle: const Text('Dark, light, or system')),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(
                          value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {widget.themeMode},
                    onSelectionChanged: (values) =>
                        widget.onThemeChanged(values.single),
                  )),
              ListTile(
                  title: const Text('Sign out'),
                  leading: const Icon(Icons.logout),
                  onTap: () => FirebaseAuth.instance.signOut()),
            ])
          : tab == 3
              ? const Center(child: Text('Reports are not available yet.'))
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: bookingsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                          child: Text(
                              'Unable to load bookings. Check your connection and try again.'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final bookings = snapshot.data!;
                    final confirmed = bookings
                        .where((b) => b['status'] == 'confirmed')
                        .toList();
                    final value = confirmed.fold<int>(
                        0,
                        (sum, b) =>
                            sum + ((b['totalPaise'] as num?)?.toInt() ?? 0));
                    if (tab == 0) {
                      return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(DateFormat('MMMM yyyy').format(month),
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            _SummaryCard('Bookings', '${confirmed.length}',
                                Icons.calendar_today_outlined),
                            _SummaryCard('Booking value', money(value),
                                Icons.currency_rupee),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const AddBooking())),
                                icon: const Icon(Icons.add),
                                label: const Text('Add booking')),
                            const SizedBox(height: 24),
                            Text('Upcoming bookings',
                                style: Theme.of(context).textTheme.titleLarge),
                            ...confirmed.map((b) => _BookingTile(b)),
                          ]);
                    }
                    if (tab == 1) {
                      return _Calendar(
                        month: month,
                        bookings: bookings,
                        onMonthChanged: changeMonth,
                      );
                    }
                    return ListView(children: [
                      if (bookings.isEmpty)
                        const ListTile(
                            title: Text('No bookings for this month')),
                      ...bookings.map((b) => _BookingTile(b)),
                    ]);
                  },
                ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Icon(icon),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label),
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                ])),
          ])));
}

class _BookingTile extends StatelessWidget {
  const _BookingTile(this.booking);
  final Map<String, dynamic> booking;
  @override
  Widget build(BuildContext context) => Card(
          child: ListTile(
        title: Text(booking['guestName']?.toString() ?? 'Guest'),
        subtitle: Text(
            '${booking['checkInDate']} → ${booking['checkOutDate']} · ${booking['status']}'),
        trailing: Text(money((booking['totalPaise'] as num?)?.toInt() ?? 0)),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Booking ${booking['id']}',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        Text('Guest: ${booking['guestName']}'),
                        Text('Phone: ${booking['phone']}'),
                        Text('Check-in: ${booking['checkInDate']} · 11 AM'),
                        Text('Check-out: ${booking['checkOutDate']} · 11 AM'),
                        Text(
                            'Amount: ${money((booking['totalPaise'] as num?)?.toInt() ?? 0)}'),
                        if (booking['status'] == 'confirmed') ...[
                          const SizedBox(height: 20),
                          Row(children: [
                            Expanded(
                                child: FilledButton.icon(
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit booking'),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            AddBooking(booking: booking)));
                              },
                            )),
                            const SizedBox(width: 12),
                            Expanded(
                                child: OutlinedButton(
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                          title: const Text(
                                              'Cancel this booking?'),
                                          content: const Text(
                                              'The record will be retained and the date will become available.'),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(
                                                    dialogContext, false),
                                                child:
                                                    const Text('Keep booking')),
                                            FilledButton(
                                                onPressed: () => Navigator.pop(
                                                    dialogContext, true),
                                                child: const Text(
                                                    'Cancel booking')),
                                          ],
                                        ));
                                if (confirmed != true) return;
                                try {
                                  await BookingRepository()
                                      .cancel(booking['id'] as String);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Unable to cancel. Check your connection and try again.')));
                                  }
                                }
                              },
                              child: const Text('Cancel booking'),
                            )),
                          ]),
                        ],
                      ]))),
        ),
      ));
}

class _Calendar extends StatelessWidget {
  const _Calendar(
      {required this.month,
      required this.bookings,
      required this.onMonthChanged});
  final DateTime month;
  final List<Map<String, dynamic>> bookings;
  final ValueChanged<DateTime> onMonthChanged;
  @override
  Widget build(BuildContext context) {
    final firstOffset = DateTime(month.year, month.month, 1).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((days + firstOffset + 6) ~/ 7) * 7;
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
            onPressed: () =>
                onMonthChanged(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left)),
        Text(DateFormat('MMMM yyyy').format(month),
            style: Theme.of(context).textTheme.titleLarge),
        IconButton(
            onPressed: () =>
                onMonthChanged(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right)),
      ]),
      Row(children: [
        for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
          Expanded(child: Center(child: Text(day))),
      ]),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: .72,
            crossAxisSpacing: 3,
            mainAxisSpacing: 4),
        itemCount: cells,
        itemBuilder: (context, index) {
          final date =
              DateTime(month.year, month.month, 1 + index - firstOffset);
          final inMonth = date.month == month.month;
          final weekend = date.weekday >= 6;
          final occupied = bookings.where((b) {
            if (b['status'] != 'confirmed') return false;
            final key = dateKey(date);
            return (b['checkInDate'] as String? ?? '').compareTo(key) <= 0 &&
                (b['checkOutDate'] as String? ?? '').compareTo(key) > 0;
          }).toList();
          return InkWell(
            onTap: !inMonth
                ? null
                : () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      builder: (_) => Padding(
                          padding: const EdgeInsets.all(20),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(DateFormat('dd MMM yyyy').format(date)),
                            const SizedBox(height: 12),
                            if (occupied.isNotEmpty)
                              ...occupied.map((b) => _BookingTile(b))
                            else
                              FilledButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                AddBooking(initialDate: date)));
                                  },
                                  child: const Text('Add booking')),
                          ])),
                    ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: weekend
                    ? Border.all(color: const Color(0xFF8873FA), width: 1.2)
                    : null,
                color: occupied.isNotEmpty
                    ? const Color(0xFF19664F)
                    : weekend
                        ? const Color(0xFF40316D).withValues(alpha: .55)
                        : Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              child: Column(children: [
                Text('${date.day}',
                    style: TextStyle(
                        color:
                            inMonth ? null : Theme.of(context).disabledColor)),
                if (occupied.isNotEmpty)
                  Text(
                    occupied.first['guestName']?.toString().split(' ').first ??
                        'Booked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                if (occupied.isNotEmpty)
                  Text(money((occupied.first['totalPaise'] as num).toInt()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white)),
              ]),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      const Text(
          'Green: booked · Violet border: Saturday / Sunday\nEach slot is 11 AM to 11 AM the next day.\nAn internet connection is required to confirm bookings.'),
    ]);
  }
}

class AddBooking extends StatefulWidget {
  const AddBooking({super.key, this.initialDate, this.booking});
  final DateTime? initialDate;
  final Map<String, dynamic>? booking;
  @override
  State<AddBooking> createState() => _AddBookingState();
}

class _AddBookingState extends State<AddBooking> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final amount = TextEditingController();
  DateTimeRange? dates;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final existing = widget.booking;
    if (existing != null) {
      name.text = existing['guestName'] as String;
      phone.text = existing['phone'] as String;
      amount.text = ((existing['totalPaise'] as int) / 100).toStringAsFixed(2);
      final day = DateTime.parse(existing['checkInDate'] as String);
      dates = DateTimeRange(
          start: day, end: DateTime(day.year, day.month, day.day + 1));
    }
    if (widget.initialDate != null) {
      dates = DateTimeRange(
          start: widget.initialDate!,
          end: widget.initialDate!.add(const Duration(days: 1)));
    }
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    amount.dispose();
    super.dispose();
  }

  Future<void> pickDates() async {
    final start =
        dates?.start ?? widget.initialDate ?? propertyDate(DateTime.now());
    final day = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: start,
    );
    if (day != null && mounted) {
      setState(() => dates = DateTimeRange(
            start: day,
            end: DateTime(day.year, day.month, day.day + 1),
          ));
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      return;
    }
    if (dates == null || !dates!.end.isAfter(dates!.start)) {
      setState(() => error = 'Choose a check-in date.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final bookingId = await BookingRepository().save(
        guestName: name.text.trim(),
        phone: phone.text.trim(),
        day: dates!.start,
        totalPaise: parsePaise(amount.text)!,
        id: widget.booking?['id'] as String?,
        notes: widget.booking?['notes'] as String? ?? '',
        source: widget.booking?['source'] as String? ?? 'phone',
        guestCount: widget.booking?['guestCount'] as int? ?? 1,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Booking saved: $bookingId')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Unable to save: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title:
                Text(widget.booking == null ? 'Add Booking' : 'Edit Booking')),
        body: Form(
            key: form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Guest name'),
                  validator: (v) =>
                      (v?.trim().length ?? 0) < 2 ? 'Enter guest name' : null),
              TextFormField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v?.trim().length ?? 0) < 8 ? 'Enter valid phone' : null),
              ListTile(
                  title:
                      const Text('24-hour stay · 11 AM check-in / check-out'),
                  subtitle: Text(
                    dates == null
                        ? 'Select check-in date'
                        : '${dateKey(dates!.start)} → ${dateKey(dates!.end)}',
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: pickDates),
              TextFormField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Total amount (₹)'),
                  validator: (v) => parsePaise(v ?? '') == null
                      ? 'Enter a valid amount, with up to 2 decimal places'
                      : null),
              const SizedBox(height: 22),
              FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Saving…' : 'Save Booking')),
              if (error != null)
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
            ])),
      );
}

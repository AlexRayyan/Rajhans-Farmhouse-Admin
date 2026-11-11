import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String dateKey(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
String money(int paise) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format(paise / 100);

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.themeMode, required this.onThemeChanged});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int tab = 0;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  final db = FirebaseFirestore.instance;
  @override
  Widget build(BuildContext context) {
    final names = ['Home', 'Calendar', 'Bookings', 'Reports', 'Settings'];
    final monthEnd = DateTime(month.year, month.month + 1);
    return Scaffold(
      appBar: AppBar(title: Text(tab == 0 ? 'Rajhans Farmhouse' : names[tab]), actions: [
        IconButton(tooltip: 'Add booking', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBooking())), icon: const Icon(Icons.add_circle_outline)),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.book_outlined), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
      body: tab == 4 ? ListView(children: [
        ListTile(title: const Text('Appearance'), subtitle: const Text('Dark, light, or system')),
        ...ThemeMode.values.map((value) => RadioListTile<ThemeMode>(
          title: Text(value.name), value: value, groupValue: widget.themeMode, onChanged: (v) { if (v != null) widget.onThemeChanged(v); },
        )),
        ListTile(title: const Text('Sign out'), leading: const Icon(Icons.logout), onTap: () => FirebaseAuth.instance.signOut()),
      ]) : tab == 3 ? const Center(child: Text('Reports will arrive in Phase 2')) :
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: db.collection('bookings').where('checkInDate', isGreaterThanOrEqualTo: dateKey(month))
          .where('checkInDate', isLessThan: dateKey(monthEnd)).limit(250).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Unable to load bookings: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final bookings = snapshot.data!.docs.map((x) => <String, dynamic>{'id': x.id, ...x.data()}).toList();
          final confirmed = bookings.where((b) => b['status'] == 'confirmed').toList();
          final value = confirmed.fold<int>(0, (sum, b) => sum + ((b['totalPaise'] as num?)?.toInt() ?? 0));
          if (tab == 0) return ListView(padding: const EdgeInsets.all(16), children: [
            Text(DateFormat('MMMM yyyy').format(month), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _SummaryCard('Bookings', '${confirmed.length}', Icons.calendar_today_outlined),
            _SummaryCard('Booking value', money(value), Icons.currency_rupee),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBooking())), icon: const Icon(Icons.add), label: const Text('Add booking')),
            const SizedBox(height: 24),
            Text('Upcoming bookings', style: Theme.of(context).textTheme.titleLarge),
            ...confirmed.map((b) => _BookingTile(b)),
          ]);
          if (tab == 1) return _Calendar(
            month: month, bookings: bookings, onMonthChanged: (m) => setState(() => month = m),
          );
          return ListView(children: [
            if (bookings.isEmpty) const ListTile(title: Text('No bookings for this month')),
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
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
    Icon(icon), const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label), Text(value, style: Theme.of(context).textTheme.headlineSmall),
    ])),
  ])));
}

class _BookingTile extends StatelessWidget {
  const _BookingTile(this.booking);
  final Map<String, dynamic> booking;
  @override
  Widget build(BuildContext context) => Card(child: ListTile(
    title: Text(booking['guestName']?.toString() ?? 'Guest'),
    subtitle: Text('${booking['checkInDate']} → ${booking['checkOutDate']} · ${booking['status']}'),
    trailing: Text(money((booking['totalPaise'] as num?)?.toInt() ?? 0)),
    onTap: () => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (_) =>
      SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Booking ${booking['id']}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text('Guest: ${booking['guestName']}'),
        Text('Phone: ${booking['phone']}'),
        Text('Check-in: ${booking['checkInDate']}'),
        Text('Check-out: ${booking['checkOutDate']}'),
        Text('Amount: ${money((booking['totalPaise'] as num?)?.toInt() ?? 0)}'),
      ]))),
    ),
  ));
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.month, required this.bookings, required this.onMonthChanged});
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
        IconButton(onPressed: () => onMonthChanged(DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
        Text(DateFormat('MMMM yyyy').format(month), style: Theme.of(context).textTheme.titleLarge),
        IconButton(onPressed: () => onMonthChanged(DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
      ]),
      const Row(children: [
        for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
          Expanded(child: Center(child: Text(day))),
      ]),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: .72, crossAxisSpacing: 3, mainAxisSpacing: 4),
        itemCount: cells,
        itemBuilder: (context, index) {
          final date = DateTime(month.year, month.month, 1 + index - firstOffset);
          final inMonth = date.month == month.month;
          final weekend = date.weekday >= 6;
          final occupied = bookings.where((b) {
            if (b['status'] != 'confirmed') return false;
            final key = dateKey(date);
            return (b['checkInDate'] as String? ?? '') .compareTo(key) <= 0 &&
                (b['checkOutDate'] as String? ?? '').compareTo(key) > 0;
          }).toList();
          return InkWell(
            onTap: !inMonth ? null : () => showModalBottomSheet<void>(
              context: context, showDragHandle: true, builder: (_) => Padding(padding: const EdgeInsets.all(20), child:
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(DateFormat('dd MMM yyyy').format(date)),
                  const SizedBox(height: 12),
                  if (occupied.isNotEmpty) ...occupied.map((b) => _BookingTile(b))
                  else FilledButton(onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AddBooking(initialDate: date)));
                  }, child: const Text('Add booking')),
                ])),
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: occupied.isNotEmpty ? const Color(0xFF19664F) :
                    weekend ? const Color(0xFF40316D).withValues(alpha: .55) :
                    Theme.of(context).colorScheme.surfaceContainerHigh,
              ),
              child: Column(children: [
                Text('${date.day}', style: TextStyle(color: inMonth ? null : Theme.of(context).disabledColor)),
                if (occupied.isNotEmpty) Text(
                  occupied.first['guestName']?.toString().split(' ').first ?? 'Booked',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
              ]),
            ),
          );
        },
      ),
      const SizedBox(height: 16),
      const Text('Green: booked · Violet: weekends · Select a free date to add a booking'),
    ]);
  }
}

class AddBooking extends StatefulWidget {
  const AddBooking({super.key, this.initialDate});
  final DateTime? initialDate;
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
    if (widget.initialDate != null) {
      dates = DateTimeRange(start: widget.initialDate!, end: widget.initialDate!.add(const Duration(days: 1)));
    }
  }
  @override
  void dispose() { name.dispose(); phone.dispose(); amount.dispose(); super.dispose(); }
  Future<void> pickDates() async {
    final start = widget.initialDate ?? DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: dates ?? DateTimeRange(start: start, end: start.add(const Duration(days: 1))),
    );
    if (range != null) setState(() => dates = range);
  }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (dates == null || !dates!.end.isAfter(dates!.start)) {
      setState(() => error = 'Choose at least one night');
      return;
    }
    setState(() { saving = true; error = null; });
    try {
      final paise = ((double.parse(amount.text.trim()) * 100).round());
      final response = await FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('createBooking').call({
        'guestName': name.text.trim(),
        'phone': phone.text.trim(),
        'checkInDate': dateKey(dates!.start),
        'checkOutDate': dateKey(dates!.end),
        'totalPaise': paise,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking saved: ${response.data['bookingId']}')));
        Navigator.pop(context);
      }
    } catch (e) { if (mounted) setState(() => error = 'Unable to save: $e'); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Add Booking')),
    body: Form(key: form, child: ListView(padding: const EdgeInsets.all(20), children: [
      TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Guest name'),
        validator: (v) => (v?.trim().length ?? 0) < 2 ? 'Enter guest name' : null),
      TextFormField(controller: phone, decoration: const InputDecoration(labelText: 'Phone number'),
        keyboardType: TextInputType.phone, validator: (v) => (v?.trim().length ?? 0) < 8 ? 'Enter valid phone' : null),
      ListTile(title: const Text('Check-in and check-out'), subtitle: Text(
        dates == null ? 'Select dates' : '${dateKey(dates!.start)} → ${dateKey(dates!.end)}',
      ), trailing: const Icon(Icons.calendar_month), onTap: pickDates),
      TextFormField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Total amount (₹)'),
        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter positive amount' : null),
      const SizedBox(height: 22),
      FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Saving…' : 'Save Booking')),
      if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ])),
  );
}

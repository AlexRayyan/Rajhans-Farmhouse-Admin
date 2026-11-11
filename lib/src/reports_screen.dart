import 'package:flutter/material.dart';
import 'booking_domain.dart';
import 'ui.dart';

class BookingReport {
  BookingReport(this.month, List<Booking> bookings) {
    arrivals = bookings
        .where((b) =>
            b.arrival.year == month.year && b.arrival.month == month.month)
        .toList();
    active = arrivals.where((b) => b.status == 'confirmed').toList();
    final days = DateTime(month.year, month.month + 1, 0).day;
    occupied = List.generate(
        days,
        (i) => bookings
            .any((b) => b.occupies(DateTime(month.year, month.month, i + 1))));
  }
  final DateTime month;
  late final List<Booking> arrivals, active;
  late final List<bool> occupied;
  int get total => active.fold(0, (sum, b) => sum + b.totalPaise);
  int get paid => active.fold(0, (sum, b) => sum + b.paidPaise);
  int get outstanding => total - paid;
  int get occupiedNights => occupied.where((v) => v).length;
  int get cancellations =>
      arrivals.where((b) => b.status == 'cancelled').length;
  int get averageStayTenths => active.isEmpty
      ? 0
      : (active.fold<int>(0, (sum, b) => sum + b.nights) * 10 / active.length)
          .round();
  Map<String, int> get sources {
    final result = <String, int>{};
    for (final b in active) {
      result[b.source] = (result[b.source] ?? 0) + 1;
    }
    return result;
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen(
      {super.key,
      required this.month,
      required this.bookings,
      required this.onMonthChanged});
  final DateTime month;
  final List<Booking> bookings;
  final ValueChanged<DateTime> onMonthChanged;
  @override
  Widget build(BuildContext context) {
    final report = BookingReport(month, bookings);
    final nights = report.occupiedNights, days = report.occupied.length;
    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        children: [
          MonthControl(month: month, onChanged: onMonthChanged),
          const SizedBox(height: 16),
          Text('Monthly performance',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('Occupancy, payments and where your bookings come from.'),
          const SizedBox(height: 20),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  const Icon(Icons.pie_chart_outline, color: violet),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Occupancy',
                          style: Theme.of(context).textTheme.titleMedium)),
                  Text('${(nights / days * 100).round()}%',
                      style: Theme.of(context).textTheme.headlineSmall)
                ]),
                const SizedBox(height: 16),
                ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: nights / days, minHeight: 12, color: violet)),
                const SizedBox(height: 12),
                Text(
                    '$nights booked nights · ${days - nights} available nights'),
                const SizedBox(height: 22),
                Text('Weekly occupied nights',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 14),
                SizedBox(
                    height: 108,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var week = 0; week < (days / 7).ceil(); week++)
                            Expanded(
                                child: _WeekBar(
                                    index: week,
                                    values: report.occupied
                                        .skip(week * 7)
                                        .take(7)
                                        .toList()))
                        ])),
              ])),
          const SizedBox(height: 18),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Payments & balance',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text('For active bookings checking in this month',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 18),
                _Amount('Booking value', report.total, violet),
                const SizedBox(height: 12),
                _Amount('Paid / advance recorded', report.paid, green),
                const SizedBox(height: 12),
                _Amount('Remaining balance', report.outstanding, amber),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                    value: report.total == 0 ? 0 : report.paid / report.total,
                    color: green,
                    minHeight: 7),
                const SizedBox(height: 10),
                Text(report.total == 0
                    ? 'No active arrivals this month.'
                    : '${(report.paid / report.total * 100).round()}% of booking value recorded as paid'),
                const SizedBox(height: 12),
                const Text(
                    'Recorded by the admin; this is not a bank reconciliation or cash-flow statement.',
                    style: TextStyle(fontSize: 11)),
              ])),
          const SizedBox(height: 18),
          Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Booking insights',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 18),
                _Insight('Active arrivals', '${report.active.length}'),
                _Insight('Cancelled arrivals', '${report.cancellations}'),
                _Insight(
                    'Average booking',
                    report.active.isEmpty
                        ? '—'
                        : money((report.total / report.active.length).round())),
                _Insight(
                    'Average stay',
                    report.active.isEmpty
                        ? '—'
                        : '${(report.averageStayTenths / 10).toStringAsFixed(1)} nights'),
                const Divider(height: 28),
                Text('Booking sources',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                if (report.sources.isEmpty)
                  const Text('Sources appear when bookings are added.'),
                for (final entry in report.sources.entries)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                              child: Text(entry.key == 'walk-in'
                                  ? 'Walk-in'
                                  : entry.key == 'whatsapp'
                                      ? 'WhatsApp'
                                      : entry.key == 'phone'
                                          ? 'Phone'
                                          : 'Other')),
                          Text('${entry.value}')
                        ]),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                            value: entry.value / report.active.length,
                            color: violet,
                            minHeight: 5),
                      ])),
              ])),
          const SizedBox(height: 14),
          const Text(
              'Occupancy includes nights from stays that began in another month. Payment and arrival insights count the full booking once, in its check-in month.',
              style: TextStyle(fontSize: 12)),
        ]);
  }
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({required this.index, required this.values});
  final int index;
  final List<bool> values;
  @override
  Widget build(BuildContext context) {
    final count = values.where((v) => v).length;
    return Semantics(
        label: 'Week ${index + 1}: $count occupied nights',
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('$count'),
          const SizedBox(height: 5),
          AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: count == 0 ? 4 : count / 7 * 58,
              width: 26,
              decoration: BoxDecoration(
                  color: violet.withValues(alpha: count == 0 ? .2 : 1),
                  borderRadius: BorderRadius.circular(5))),
          const SizedBox(height: 8),
          Text('W${index + 1}', style: Theme.of(context).textTheme.bodySmall)
        ]));
  }
}

class _Amount extends StatelessWidget {
  const _Amount(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Text(money(value),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 17))
      ]);
}

class _Insight extends StatelessWidget {
  const _Insight(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold))
      ]));
}

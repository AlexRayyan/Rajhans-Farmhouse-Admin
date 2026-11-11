import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'booking_domain.dart';

String money(int paise) => NumberFormat.currency(
        locale: 'en_IN', symbol: '₹', decimalDigits: paise % 100 == 0 ? 0 : 2)
    .format(paise / 100);
String readableDate(DateTime day) =>
    DateFormat('EEEE, dd-MMM-yyyy', 'en_US').format(day);
const violet = Color(0xFF7560FF);
const green = Color(0xFF36D69A);
const amber = Color(0xFFF0B35C);

ThemeData farmhouseTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor:
        dark ? const Color(0xFF101525) : const Color(0xFFF5F6FB),
    colorScheme:
        ColorScheme.fromSeed(seedColor: violet, brightness: brightness),
    cardTheme: CardThemeData(
        color: dark ? const Color(0xFF192139) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF192139) : Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: violet))),
  );
}

class Panel extends StatelessWidget {
  const Panel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Card(
      margin: EdgeInsets.zero, child: Padding(padding: padding, child: child));
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Confirmed' || 'Available' => green,
      'Checked in' => const Color(0xFF64B5F6),
      'Cancelled' => const Color(0xFFFF7789),
      'Completed' => const Color(0xFFB69AFF),
      _ => amber
    };
    final icon = switch (label) {
      'Confirmed' => Icons.check_circle_outline,
      'Checked in' => Icons.login,
      'Cancelled' => Icons.cancel_outlined,
      'Completed' => Icons.task_alt,
      'Available' => Icons.event_available_outlined,
      _ => Icons.schedule
    };
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: color.withValues(alpha: .35))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)))
            ])));
  }
}

class MonthControl extends StatelessWidget {
  const MonthControl({super.key, required this.month, required this.onChanged});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: [
        IconButton(
            tooltip: 'Previous month',
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
            icon: const Icon(Icons.chevron_left)),
        Expanded(
            child: TextButton(
                onPressed: () async {
                  final day = await showDatePicker(
                      context: context,
                      initialDate: month,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                      initialDatePickerMode: DatePickerMode.year);
                  if (day != null) onChanged(DateTime(day.year, day.month));
                },
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                      child: Text(DateFormat('MMMM yyyy').format(month),
                          style: Theme.of(context).textTheme.titleMedium)),
                  const Icon(Icons.expand_more, size: 18)
                ]))),
        IconButton(
            tooltip: 'Next month',
            onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
            icon: const Icon(Icons.chevron_right)),
      ]);
}

class BookingCard extends StatelessWidget {
  const BookingCard(this.booking, {super.key, required this.onTap});
  final Booking booking;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                StayDateTile(date: booking.arrival),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(booking.guestName,
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                          '${readableDate(booking.arrival)} → ${readableDate(booking.departure)}',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 10),
                      Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            StatusBadge(booking.statusLabel()),
                            Text(money(booking.totalPaise),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))
                          ]),
                    ])),
                const Icon(Icons.chevron_right, size: 18),
              ]))));
}

class BookingDateCard extends StatelessWidget {
  const BookingDateCard(
      {super.key, required this.label, required this.date, this.onTap});
  final String label;
  final DateTime date;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Panel(
      padding: EdgeInsets.zero,
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.calendar_month_outlined,
                          size: 17, color: violet),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(label,
                              style: Theme.of(context).textTheme.bodySmall))
                    ]),
                    const SizedBox(height: 10),
                    Center(child: StayDateTile(date: date)),
                    const SizedBox(height: 8),
                    Center(
                        child: Text('${date.year} · 11:00 AM',
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: violet, fontSize: 12))),
                  ]))));
}

/// Shared by upcoming stays and all check-in/check-out cards.
class StayDateTile extends StatelessWidget {
  const StayDateTile({super.key, required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) => Semantics(
      label: readableDate(date),
      excludeSemantics: true,
      child: Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: violet.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(14)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(DateFormat('EEE', 'en_US').format(date),
                style: const TextStyle(
                    color: violet, fontWeight: FontWeight.w600)),
            Text('${date.day}',
                style: Theme.of(context).textTheme.headlineSmall),
            Text(DateFormat('MMM', 'en_US').format(date),
                style: Theme.of(context).textTheme.labelSmall),
          ])));
}

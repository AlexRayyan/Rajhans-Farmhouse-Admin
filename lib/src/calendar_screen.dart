import 'package:flutter/material.dart';
import 'booking_domain.dart';
import 'ui.dart';

class BookingCalendar extends StatefulWidget {
  const BookingCalendar(
      {super.key,
      required this.month,
      required this.bookings,
      required this.onMonthChanged,
      required this.onAdd,
      required this.onDetails});
  final DateTime month;
  final List<Booking> bookings;
  final ValueChanged<DateTime> onMonthChanged, onAdd;
  final ValueChanged<Booking> onDetails;
  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
  late DateTime selected;
  DateTime initialSelection() {
    final today = propertyDay(DateTime.now());
    return today.month == widget.month.month && today.year == widget.month.year
        ? today
        : widget.month;
  }

  @override
  void initState() {
    super.initState();
    selected = initialSelection();
  }

  @override
  void didUpdateWidget(BookingCalendar old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) selected = initialSelection();
  }

  Booking? at(DateTime day) {
    for (final booking in widget.bookings) {
      if (booking.occupies(day)) return booking;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.month,
        offset = DateTime(widget.month.year, widget.month.month).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + days + 6) ~/ 7) * 7;
    final chosen = at(selected), past = !canBookDay(selected);
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.5);
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          MonthControl(month: month, onChanged: widget.onMonthChanged),
          const SizedBox(height: 12),
          Row(children: [
            for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                          color: ['Sat', 'Sun'].contains(day)
                              ? violet.withValues(alpha: .14)
                              : null,
                          borderRadius: BorderRadius.circular(8)),
                      child: Center(
                          child: Text(day,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: ['Sat', 'Sun'].contains(day)
                                      ? violet
                                      : null,
                                  fontWeight: FontWeight.bold)))))
          ]),
          const SizedBox(height: 8),
          GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: .67 / textScale,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 5),
              itemBuilder: (context, index) {
                final number = index - offset + 1;
                if (number < 1 || number > days) return const SizedBox.shrink();
                final day = DateTime(month.year, month.month, number),
                    booking = at(DateTime(month.year, month.month, number));
                final active = calendarDay(day) == calendarDay(selected),
                    weekend = day.weekday >= 6,
                    old = !canBookDay(day);
                return Semantics(
                    label:
                        '${readableDate(day)}, ${booking == null ? (old ? 'past date' : 'available') : 'booked by ${booking.guestName}'}',
                    button: true,
                    selected: active,
                    child: InkWell(
                        key: ValueKey('calendar-day-$number'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => selected = day),
                        child: AnimatedContainer(
                            duration: const Duration(milliseconds: 170),
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: active
                                    ? const LinearGradient(
                                        colors: [violet, Color(0xFF553DEB)])
                                    : null,
                                color: active
                                    ? null
                                    : booking != null
                                        ? green.withValues(alpha: .17)
                                        : weekend
                                            ? violet.withValues(alpha: .1)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainer,
                                border: Border.all(
                                    color: active
                                        ? const Color(0xFFBAAAFF)
                                        : weekend
                                            ? violet.withValues(alpha: .6)
                                            : Colors.transparent,
                                    width: active ? 1.5 : 1)),
                            child: Column(children: [
                              Text('$number',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: active
                                          ? Colors.white
                                          : old
                                              ? Theme.of(context).disabledColor
                                              : null)),
                              const SizedBox(height: 5),
                              if (booking != null) ...[
                                Text(booking.guestName.split(' ').first,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: active ? Colors.white : green)),
                                Text(money(booking.totalPaise),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: active ? Colors.white : green)),
                                const SizedBox(height: 3),
                                Icon(Icons.check_circle,
                                    size: 10,
                                    color: active ? Colors.white : green)
                              ],
                            ]))));
              }),
          const SizedBox(height: 16),
          const Wrap(spacing: 14, runSpacing: 8, children: [
            _Legend(green, 'Booked'),
            _Legend(violet, 'Selected / weekend'),
            _Legend(Colors.grey, 'Past date')
          ]),
          const SizedBox(height: 20),
          AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Panel(
                  key: ValueKey('${selected.toIso8601String()}-${chosen?.id}'),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(readableDate(selected),
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        StatusBadge(chosen != null
                            ? chosen.statusLabel()
                            : past
                                ? 'Past date'
                                : 'Available'),
                        const SizedBox(height: 14),
                        if (chosen != null) ...[
                          Text(chosen.guestName,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 5),
                          Text(
                              '${chosen.guestCount} guests · ${money(chosen.totalPaise)}'),
                          const SizedBox(height: 15),
                          SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                  onPressed: () => widget.onDetails(chosen),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: const Text('View booking')))
                        ] else ...[
                          Text(past
                              ? 'Past dates cannot be booked.'
                              : 'Check-in is at 11 AM. Choose your check-out date when booking.'),
                          const SizedBox(height: 15),
                          SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                  onPressed: past
                                      ? null
                                      : () => widget.onAdd(selected),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add booking')))
                        ],
                      ]))),
        ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11))
      ]);
}

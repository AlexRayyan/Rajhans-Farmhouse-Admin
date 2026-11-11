import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'booking_repository.dart';
import 'add_booking.dart';
import 'native_services.dart';
import 'ui.dart';

class BookingDetails extends StatefulWidget {
  const BookingDetails({super.key, required this.booking, required this.store});
  final Booking booking;
  final BookingStore store;
  @override
  State<BookingDetails> createState() => _BookingDetailsState();
}

class _BookingDetailsState extends State<BookingDetails> {
  late final Stream<Booking?> updates =
      widget.store.watchBooking(widget.booking.id);
  bool working = false;
  Future<void> receipt(Booking booking, String action) async {
    if (working) return;
    setState(() => working = true);
    try {
      await NativeServices.receipt(booking, action: action);
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message ?? 'Unable to open the receipt.')));
      }
    } on MissingPluginException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('PDF sharing is not available on this device yet.')));
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> cancel(Booking booking) async {
    final agree = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('Cancel this booking?'),
                content: const Text(
                    'All reserved nights will become available. The booking record will be retained.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: const Text('Keep booking')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, true),
                      child: const Text('Cancel booking'))
                ]));
    if (agree != true || !mounted) return;
    setState(() => working = true);
    try {
      await widget.store.cancel(booking.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Unable to cancel. Please check your connection and try again.')));
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Booking?>(
      stream: updates,
      initialData: widget.booking,
      builder: (context, snapshot) {
        final booking = snapshot.data ?? widget.booking;
        return Scaffold(
            appBar: AppBar(title: const Text('Booking Details'), actions: [
              if (booking.status == 'confirmed')
                IconButton(
                    tooltip: 'Edit booking',
                    onPressed: working
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => AddBooking(
                                    booking: booking, store: widget.store))),
                    icon: const Icon(Icons.edit_outlined))
            ]),
            body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                children: [
                  Center(
                      child: StatusBadge(booking.statusLabel(),
                          onTap: () => showModalBottomSheet<void>(
                              context: context,
                              showDragHandle: true,
                              builder: (_) => SafeArea(
                                  child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Text(booking.status == 'cancelled'
                                          ? 'This booking has been cancelled and all of its nights are available again.'
                                          : 'This booking reserves ${booking.nights} nights, from 11 AM on ${readableDate(booking.arrival)} to 11 AM on ${readableDate(booking.departure)}.')))))),
                  const SizedBox(height: 22),
                  Panel(
                      child: Column(children: [
                    Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [violet, Color(0xFF9B7CFF)]),
                            borderRadius: BorderRadius.circular(25)),
                        child: const Icon(Icons.villa_outlined,
                            color: Colors.white, size: 40)),
                    const SizedBox(height: 16),
                    Text(booking.guestName,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(booking.phone),
                    const SizedBox(height: 14),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.groups_outlined,
                          size: 18, color: violet),
                      const SizedBox(width: 6),
                      Text('${booking.guestCount} guests'),
                      const SizedBox(width: 16),
                      const Icon(Icons.nights_stay_outlined,
                          size: 18, color: violet),
                      const SizedBox(width: 6),
                      Text(
                          '${booking.nights} ${booking.nights == 1 ? 'night' : 'nights'}')
                    ]),
                  ])),
                  const SizedBox(height: 16),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: BookingDateCard(
                            label: 'Check-in', date: booking.arrival)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: BookingDateCard(
                            label: 'Check-out', date: booking.departure))
                  ]),
                  const SizedBox(height: 16),
                  Panel(
                      child: Column(children: [
                    _Row('Booking amount', money(booking.totalPaise),
                        large: true),
                    const Divider(height: 28),
                    _Row('Advance / paid', money(booking.paidPaise)),
                    const SizedBox(height: 14),
                    _Row('Balance due',
                        money(booking.totalPaise - booking.paidPaise),
                        color: amber),
                    const SizedBox(height: 14),
                    const Text(
                        'Payments shown are recorded by the farmhouse admin.',
                        style: TextStyle(fontSize: 12))
                  ])),
                  const SizedBox(height: 16),
                  Panel(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        _Row('Booking source', booking.source),
                        const SizedBox(height: 12),
                        Text('Booking ID',
                            style: Theme.of(context).textTheme.bodySmall),
                        SelectableText(booking.displayId,
                            style: Theme.of(context).textTheme.labelMedium),
                        if (booking.notes.isNotEmpty) ...[
                          const Divider(height: 28),
                          Text('Notes',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          Text(booking.notes)
                        ]
                      ])),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                      onPressed:
                          working ? null : () => receipt(booking, 'whatsapp'),
                      icon: const Icon(Icons.send_outlined),
                      label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Send receipt via WhatsApp'))),
                  const SizedBox(height: 8),
                  const Text(
                      'A PDF will be attached in WhatsApp. Confirm the recipient and tap Send there.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed:
                                working ? null : () => receipt(booking, 'view'),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('View receipt'))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: working
                                ? null
                                : () => receipt(booking, 'share'),
                            icon: const Icon(Icons.ios_share),
                            label: const Text('Share PDF')))
                  ]),
                  if (booking.status == 'confirmed') ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error),
                        onPressed: working ? null : () => cancel(booking),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Cancel booking'))
                  ],
                  if (working)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator())),
                  if (snapshot.hasError)
                    const Text(
                        'Live updates are unavailable. Check your connection before making changes.'),
                ]));
      });
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.large = false, this.color});
  final String label, value;
  final bool large;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        const SizedBox(width: 12),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: large ? 22 : 15,
                    fontWeight: FontWeight.w700,
                    color: color)))
      ]);
}

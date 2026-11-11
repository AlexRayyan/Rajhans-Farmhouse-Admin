import 'dart:async';
import 'booking_details.dart';
import 'guest_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'booking_repository.dart';
import 'native_services.dart';
import 'ui.dart';

class AddBooking extends StatefulWidget {
  const AddBooking({super.key, this.initialDate, this.booking, this.store});
  final DateTime? initialDate;
  final Booking? booking;
  final BookingStore? store;
  @override
  State<AddBooking> createState() => _AddBookingState();
}

class _AddBookingState extends State<AddBooking> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      amount = TextEditingController(),
      notes = TextEditingController(),
      advance = TextEditingController(text: '0');
  late final BookingStore store;
  late DateTime arrival, departure;
  int guests = 2;
  String source = 'phone';
  String paymentMode = 'advance';
  Map<String, String> occupied = {};
  bool availabilityReady = false;
  StreamSubscription<Map<String, String>>? availability;
  String? availabilityError;
  bool saving = false, readingCalls = false;
  String? error;
  List<AmountSuggestion> suggestions = amountSuggestions([]);
  @override
  void initState() {
    super.initState();
    store = widget.store ?? BookingRepository();
    final booking = widget.booking;
    arrival =
        booking?.arrival ?? widget.initialDate ?? propertyDay(DateTime.now());
    if (booking == null && !canBookDay(arrival)) {
      arrival = propertyDay(DateTime.now());
    }
    departure = booking?.departure ??
        DateTime(arrival.year, arrival.month, arrival.day + 1);
    if (booking != null) {
      name.text = booking.guestName;
      phone.text = booking.phone;
      amount.text = (booking.totalPaise / 100).toStringAsFixed(2);
      notes.text = booking.notes;
      advance.text = (booking.paidPaise / 100).toStringAsFixed(2);
      paymentMode =
          booking.paidPaise == booking.totalPaise ? 'full' : 'advance';
      guests = booking.guestCount.clamp(2, 100);
      source = booking.source;
    }
    availability = store.watchOccupiedSlots().listen((slots) {
      if (mounted) {
        setState(() {
          occupied = slots;
          availabilityReady = true;
          availabilityError = null;
        });
      }
    }, onError: (Object _) {
      if (mounted) {
        setState(() {
          availabilityReady = false;
          availabilityError =
              'Unable to load available dates. Check your connection and reopen this form.';
        });
      }
    });
    store.suggestedAmounts().then((data) {
      if (mounted) setState(() => suggestions = data);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    availability?.cancel();
    advance.dispose();
    name.dispose();
    phone.dispose();
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> pickDate(bool checkIn) async {
    if (!availabilityReady) {
      message(availabilityError ?? 'Loading available dates…');
      return;
    }
    final today = propertyDay(DateTime.now());
    final first = checkIn
        ? today
        : DateTime(arrival.year, arrival.month, arrival.day + 1);
    final last = checkIn
        ? DateTime(2100)
        : DateTime(arrival.year, arrival.month, arrival.day + maxStayNights);
    var initial = checkIn ? arrival : departure;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    bool selectable(DateTime day) => checkIn
        ? (occupied[propertyCheckIn(day).millisecondsSinceEpoch.toString()] ==
                null ||
            occupied[propertyCheckIn(day).millisecondsSinceEpoch.toString()] ==
                widget.booking?.id)
        : stayAvailable(arrival, day, occupied, excluding: widget.booking?.id);
    if (!selectable(initial)) {
      initial = first;
      while (!selectable(initial) && initial.isBefore(last)) {
        initial = DateTime(initial.year, initial.month, initial.day + 1);
      }
      if (!selectable(initial)) {
        message('No available dates in this range. Choose another check-in.');
        return;
      }
    }
    final result = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        selectableDayPredicate: selectable,
        lastDate: last,
        helpText: checkIn ? 'CHECK-IN · 11 AM' : 'CHECK-OUT · 1–31 NIGHTS');
    if (result == null || !mounted) return;
    setState(() {
      if (checkIn) {
        arrival = result;
        if (!departure.isAfter(arrival) ||
            stayNights(arrival, departure) > maxStayNights ||
            !stayAvailable(arrival, departure, occupied,
                excluding: widget.booking?.id)) {
          departure = DateTime(arrival.year, arrival.month, arrival.day + 1);
        }
      } else {
        departure = result;
      }
    });
  }

  Future<void> chooseGuests() async {
    final picked = await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (_) => GuestCountPicker(initialValue: guests));
    if (picked != null && mounted) setState(() => guests = picked);
  }

  void applyPerson(Map<String, dynamic> person) {
    phone.text = (person['number'] ?? '').toString();
    final label = (person['name'] ?? '').toString();
    if (name.text.trim().isEmpty && label.isNotEmpty) name.text = label;
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> contact() async {
    try {
      final person = await NativeServices.pickContact();
      if (person != null && mounted) applyPerson(person);
    } on PlatformException catch (e) {
      message(
          e.message ?? 'Contacts could not open. Enter the number manually.');
    } on MissingPluginException {
      message('Contact selection is not available on this device.');
    }
  }

  Future<void> recentCalls() async {
    if (readingCalls) return;
    bool allowed = false;
    try {
      allowed = await NativeServices.callLogAllowed();
    } on PlatformException {
      // The actual read below provides the actionable device error.
    } on MissingPluginException {
      message(
          'Recent calls are not available on this device. Choose Contacts instead.');
      return;
    }
    if (!mounted) return;
    final proceed = allowed ||
        await showDialog<bool>(
                context: context,
                builder: (dialog) => AlertDialog(
                        title: const Text('Choose a recent caller'),
                        content: const Text(
                            'Android may ask for call-log access. Call history stays on this phone; only the number you choose is added to the booking.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dialog, false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.pop(dialog, true),
                              child: const Text('Continue'))
                        ])) ==
            true;
    if (proceed != true || !mounted) return;
    setState(() => readingCalls = true);
    try {
      final calls = await NativeServices.recentCalls();
      if (!mounted) return;
      if (calls.isEmpty) {
        message(
            'No recent calls were found. You can choose a contact or type the number.');
        return;
      }
      final person = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (sheet) => SafeArea(
              child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * .7,
                  child: Column(children: [
                    Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text('Recent calls',
                            style: Theme.of(context).textTheme.titleLarge)),
                    Expanded(
                        child: ListView.separated(
                            itemCount: calls.length,
                            separatorBuilder: (_, i) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final row = calls[i];
                              return ListTile(
                                  leading: const CircleAvatar(
                                      child: Icon(Icons.history)),
                                  title: Text(
                                      (row['name'] ?? '').toString().isEmpty
                                          ? row['number'].toString()
                                          : row['name'].toString()),
                                  subtitle: Text(
                                      '${row['number']} · ${DateFormat('dd MMM, h:mm a').format(DateTime.fromMillisecondsSinceEpoch(row['date'] as int))}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.pop(sheet, row));
                            })),
                  ]))));
      if (person != null && mounted) applyPerson(person);
    } on PlatformException catch (e) {
      message(e.message ??
          'Call logs are unavailable. Choose Contacts or enter the number.');
    } on MissingPluginException {
      message(
          'Recent calls are not available on this device. Choose Contacts instead.');
    } finally {
      if (mounted) setState(() => readingCalls = false);
    }
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    final unchanged = widget.booking != null &&
        arrival == widget.booking!.arrival &&
        departure == widget.booking!.departure;
    if (!canBookDay(arrival) && !unchanged) {
      setState(() => error = 'Past dates cannot be booked.');
      return;
    }
    if (!availabilityReady ||
        !stayAvailable(arrival, departure, occupied,
            excluding: widget.booking?.id)) {
      setState(() =>
          error = 'These dates are no longer available. Choose another stay.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final savedId = await store.save(
          guestName: name.text,
          phone: phone.text,
          day: arrival,
          checkout: departure,
          totalPaise: parsePaise(amount.text)!,
          guestCount: guests,
          paidPaise: paidAmount,
          source: source,
          notes: notes.text,
          id: widget.booking?.id,
          expectedRevision: widget.booking?.revision);
      if (mounted) {
        message(
            widget.booking == null ? 'Booking confirmed' : 'Booking updated');
        if (widget.booking != null) {
          Navigator.pop(context);
        } else {
          final booking = Booking(
              id: savedId,
              guestName: name.text.trim(),
              phone: phone.text.trim(),
              checkInAt: propertyCheckIn(arrival),
              checkOutAt: propertyCheckIn(departure),
              totalPaise: parsePaise(amount.text)!,
              paidPaise: paidAmount,
              guestCount: guests,
              source: source,
              notes: notes.text);
          Navigator.pushReplacement(
              context,
              MaterialPageRoute<void>(
                  builder: (_) =>
                      BookingDetails(booking: booking, store: store)));
        }
      }
    } on BookingConflict catch (e) {
      if (mounted) setState(() => error = e.toString());
    } on ArgumentError catch (e) {
      if (mounted) setState(() => error = e.message.toString());
    } on StateError catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            error = 'Unable to save. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  int get paidAmount => paymentMode == 'full'
      ? (parsePaise(amount.text) ?? 0)
      : (parsePaise(advance.text, allowZero: true) ?? 0);

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.booking == null ? 'Add Booking' : 'Edit Booking')),
      body: Form(
          key: form,
          child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                TextFormField(
                    key: const ValueKey('guest-name'),
                    controller: name,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Customer name',
                        prefixIcon: Icon(Icons.person_outline),
                        counterText: ''),
                    validator: (value) => (value?.trim().length ?? 0) < 2
                        ? 'Enter the customer name'
                        : null),
                const SizedBox(height: 14),
                TextFormField(
                    key: const ValueKey('phone'),
                    controller: phone,
                    maxLength: 20,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Phone number',
                        hintText: '+91 98765 43210',
                        prefixIcon: Icon(Icons.phone_outlined),
                        counterText: ''),
                    validator: (value) => RegExp(r'^[+0-9 ()-]{8,20}$')
                            .hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Enter a valid phone number'),
                Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed: readingCalls ? null : recentCalls,
                      icon: const Icon(Icons.history, size: 18),
                      label: Text(
                          readingCalls ? 'Reading calls…' : 'Recent calls')),
                  TextButton.icon(
                      onPressed: contact,
                      icon: const Icon(Icons.contacts_outlined, size: 18),
                      label: const Text('Contacts'))
                ]),
                const SizedBox(height: 8),
                Panel(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                        key: const ValueKey('guest-count'),
                        leading:
                            const Icon(Icons.groups_outlined, color: violet),
                        title: const Text('Guests'),
                        subtitle: Text('$guests guests'),
                        trailing: const Icon(Icons.expand_more),
                        onTap: chooseGuests)),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                      child: BookingDateCard(
                          label: 'Check-in',
                          date: arrival,
                          onTap: () => pickDate(true))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: BookingDateCard(
                          label: 'Check-out',
                          date: departure,
                          onTap: () => pickDate(false))),
                ]),
                const SizedBox(height: 8),
                Text(
                    availabilityError ??
                        (availabilityReady
                            ? 'Booked nights are greyed out. Checkout may share the next guest’s check-in date.'
                            : 'Loading available dates…'),
                    style: Theme.of(context).textTheme.bodySmall),
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.nights_stay_outlined,
                          size: 17, color: violet),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              '${stayNights(arrival, departure)} ${stayNights(arrival, departure) == 1 ? 'night' : 'nights'} · 11 AM check-in / check-out',
                              style: Theme.of(context).textTheme.bodySmall))
                    ])),
                TextFormField(
                    key: const ValueKey('amount'),
                    controller: amount,
                    onChanged: (_) => setState(() {}),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Total booking amount',
                        prefixIcon: Icon(Icons.currency_rupee)),
                    validator: (value) => parsePaise(value ?? '') == null
                        ? 'Enter a valid amount (up to 2 decimals)'
                        : null),
                const SizedBox(height: 12),
                Text('Popular amounts',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: suggestions
                        .map((item) => ChoiceChip(
                            key: ValueKey('amount-${item.paise}'),
                            selected: parsePaise(amount.text) == item.paise,
                            avatar: item.count > 0
                                ? const Icon(Icons.trending_up,
                                    size: 16, color: green)
                                : null,
                            label: Text(money(item.paise)),
                            tooltip: item.count > 0
                                ? 'Used in ${item.count} recent bookings'
                                : 'Quick amount',
                            onSelected: (_) => setState(() {
                                  amount.text = (item.paise ~/ 100).toString();
                                })))
                        .toList()),
                const SizedBox(height: 20),
                Text('Payment details',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                      key: const ValueKey('advance-mode'),
                      label: const Text('Advance paid'),
                      selected: paymentMode == 'advance',
                      onSelected: (_) =>
                          setState(() => paymentMode = 'advance')),
                  ChoiceChip(
                      key: const ValueKey('full-mode'),
                      label: const Text('Fully paid'),
                      selected: paymentMode == 'full',
                      onSelected: (_) => setState(() => paymentMode = 'full')),
                ]),
                if (paymentMode == 'advance') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                      key: const ValueKey('advance-amount'),
                      controller: advance,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: 'Advance amount paid',
                          prefixIcon: Icon(Icons.currency_rupee),
                          helperText: 'Enter 0 if no payment received'),
                      validator: (value) {
                        final paid = parsePaise(value ?? '', allowZero: true);
                        final total = parsePaise(amount.text);
                        return paid == null || total == null || paid > total
                            ? 'Enter an advance between ₹0 and the total'
                            : null;
                      }),
                ],
                const SizedBox(height: 14),
                Panel(
                    child: Row(children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: violet),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('Remaining balance',
                          style: Theme.of(context).textTheme.titleSmall)),
                  Text(
                      money(((parsePaise(amount.text) ?? 0) - paidAmount)
                          .clamp(0, 1000000000)),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: violet))
                ])),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                    initialValue: source,
                    decoration: const InputDecoration(
                        labelText: 'Booking source',
                        prefixIcon: Icon(Icons.bookmark_outline)),
                    items: const [
                      DropdownMenuItem(value: 'phone', child: Text('Phone')),
                      DropdownMenuItem(
                          value: 'whatsapp', child: Text('WhatsApp')),
                      DropdownMenuItem(
                          value: 'walk-in', child: Text('Walk-in')),
                      DropdownMenuItem(value: 'other', child: Text('Other'))
                    ],
                    onChanged: (value) {
                      if (value != null) source = value;
                    }),
                const SizedBox(height: 16),
                TextFormField(
                    controller: notes,
                    maxLength: 1000,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        alignLabelWithHint: true)),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                FilledButton.icon(
                    key: const ValueKey('save-booking'),
                    onPressed: saving || !availabilityReady ? null : save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline),
                    label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child:
                            Text(saving ? 'Saving booking…' : 'Save booking'))),
              ])));
}

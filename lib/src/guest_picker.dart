import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class GuestCountPicker extends StatefulWidget {
  const GuestCountPicker({super.key, required this.initialValue});
  final int initialValue;
  @override
  State<GuestCountPicker> createState() => _GuestCountPickerState();
}

class _GuestCountPickerState extends State<GuestCountPicker> {
  late int selected = widget.initialValue;
  late final wheel = FixedExtentScrollController(initialItem: selected - 2);
  @override
  void dispose() {
    wheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: SizedBox(
          height: 340,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(children: [
                  Expanded(
                      child: Text('Number of guests',
                          style: Theme.of(context).textTheme.titleLarge)),
                  TextButton(
                      onPressed: () => Navigator.pop(context, selected),
                      child: const Text('Done'))
                ])),
            const Text('Choose from 2 to 100 guests'),
            const SizedBox(height: 10),
            Expanded(
                child: CupertinoPicker.builder(
                    key: const ValueKey('guest-wheel'),
                    scrollController: wheel,
                    itemExtent: 48,
                    magnification: 1.12,
                    useMagnifier: true,
                    childCount: 99,
                    onSelectedItemChanged: (index) {
                      selected = index + 2;
                    },
                    itemBuilder: (context, index) => Center(
                        child: Text('${index + 2} guests',
                            style: Theme.of(context).textTheme.titleLarge)))),
            const SizedBox(height: 18),
          ])));
}

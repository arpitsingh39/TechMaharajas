// lib/shift schedule.dart
import 'package:flutter/material.dart';

class ShiftSchedulePage extends StatefulWidget {
  const ShiftSchedulePage({super.key});
  @override
  State<ShiftSchedulePage> createState() => _ShiftSchedulePageState();
}

class _ShiftSchedulePageState extends State<ShiftSchedulePage> {
  final weekDays = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final slots = <String, List<String>>{};

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Shift Schedule', style: Theme.of(context).textTheme.headlineSmall),
            FilledButton.icon(
              onPressed: _generateDraft,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Schedule'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.75),
            itemCount: 7,
            itemBuilder: (_, i) {
              final day = weekDays[i];
              final items = slots[day] ?? [];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(day, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: items.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Chip(
                            label: Text(e),
                            avatar: const Icon(Icons.schedule, size: 18),
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                          ),
                        )).toList(),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonal(onPressed: () {}, child: const Text('Approve Draft')),
        )
      ]),
    );
  }

  void _generateDraft() {
    setState(() {
      slots.clear();
      for (final d in weekDays) {
        slots[d] = [
          'Alex • Cashier • 09:00–17:00 (draft)',
          if (d != 'Tue') 'Maria • Sales • 10:00–18:00 (draft)',
        ];
      }
    });
  }
}

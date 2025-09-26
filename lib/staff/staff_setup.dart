// lib/staff/staff set up.dart
import 'package:flutter/material.dart';

class StaffSetupPage extends StatefulWidget {
  const StaffSetupPage({super.key});
  @override
  State<StaffSetupPage> createState() => _StaffSetupPageState();
}

class _StaffSetupPageState extends State<StaffSetupPage> {
  final shopName = TextEditingController(text: 'Demo Shop');
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 18, minute: 0);
  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<String> openDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  final List<String> roles = ['Cashier', 'Sales', 'Stock'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Text('Shop Setup', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(
            controller: shopName,
            decoration: const InputDecoration(
              labelText: 'Shop Name',
              prefixIcon: Icon(Icons.storefront),
            ),
          ),
          const SizedBox(height: 12),
          Text('Business Hours', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.schedule),
                label: Text('Start ${start.format(context)}'),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: start);
                  if (t != null) setState(() => start = t);
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.schedule),
                label: Text('End ${end.format(context)}'),
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: end);
                  if (t != null) setState(() => end = t);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Open Days', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final d in days)
                FilterChip(
                  label: Text(d),
                  selected: openDays.contains(d),
                  onSelected: (v) => setState(() {
                    if (v) {
                      openDays.add(d);
                    } else {
                      openDays.remove(d);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Staff Roles', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final r in roles)
                InputChip(
                  label: Text(r),
                  onDeleted: () => setState(() => roles.remove(r)),
                ),
              ActionChip(
                label: const Text('Add role'),
                avatar: const Icon(Icons.add),
                onPressed: () async {
                  final ctrl = TextEditingController();
                  final name = await showDialog<String>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Add Role'),
                      content: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(hintText: 'Role name'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Add')),
                      ],
                    ),
                  );
                  if (name != null && name.isNotEmpty) {
                    setState(() => roles.add(name));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                final snack = SnackBar(
                  content: Text(
                    'Saved ${shopName.text} • ${_fmt(start)}–${_fmt(end)} • ${openDays.join(", ")} • ${roles.length} roles',
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(snack);
              },
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

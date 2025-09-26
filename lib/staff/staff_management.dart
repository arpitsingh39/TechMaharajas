// lib/staff/staff management.dart
import 'package:flutter/material.dart';

class StaffMember {
  String name;
  String role;
  String contact;
  // Simple display string for demo (e.g., "Mon 09:00–13:00; Fri 14:00–20:00")
  String availability;
  StaffMember({
    required this.name,
    required this.role,
    required this.contact,
    required this.availability,
  });
}

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});
  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  final roles = <String>['Cashier', 'Sales', 'Stock', 'Barista'];
  final List<StaffMember> staff = [
    StaffMember(
      name: 'Alex Smith',
      role: 'Cashier',
      contact: '555-1234',
      availability: 'Mon 09:00–17:00; Wed 09:00–17:00; Fri 09:00–17:00',
    ),
    StaffMember(
      name: 'Maria Johnson',
      role: 'Sales',
      contact: '555-5678',
      availability: 'Tue 10:00–18:00; Thu 10:00–18:00',
    ),
  ];

  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Staff Management', style: theme.textTheme.headlineSmall),
            Row(children: [
              FilledButton.icon(
                onPressed: () async {
                  final created = await showDialog<StaffMember>(
                    context: context,
                    builder: (_) => _StaffEditorDialog(roles: roles),
                  );
                  if (created != null) {
                    setState(() => staff.add(created));
                  }
                },
                icon: const Icon(Icons.person_add),
                label: const Text('Add Staff'),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            elevation: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: const Text('Employee Name'),
                    onSort: (i, asc) => _sortBy((s) => s.name, i, asc),
                  ),
                  DataColumn(
                    label: const Text('Role'),
                    onSort: (i, asc) => _sortBy((s) => s.role, i, asc),
                  ),
                  const DataColumn(label: Text('Availability')),
                  const DataColumn(label: Text('Contact')),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: [
                  for (final s in staff)
                    DataRow(cells: [
                      DataCell(Text(s.name)),
                      DataCell(Text(s.role)),
                      DataCell(Text(s.availability)),
                      DataCell(Text(s.contact)),
                      DataCell(Row(
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final updated = await showDialog<StaffMember>(
                                context: context,
                                builder: (_) => _StaffEditorDialog(
                                  roles: roles,
                                  existing: s,
                                ),
                              );
                              if (updated != null) {
                                setState(() {
                                  s.name = updated.name;
                                  s.role = updated.role;
                                  s.contact = updated.contact;
                                  s.availability = updated.availability;
                                });
                              }
                            },
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Remove staff?'),
                                  content: Text('Delete ${s.name}?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        setState(() => staff.remove(s));
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      )),
                    ]),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _sortBy(Comparable Function(StaffMember) key, int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      staff.sort((a, b) {
        final kA = key(a), kB = key(b);
        final result = Comparable.compare(kA, kB);
        return ascending ? result : -result;
      });
    });
  }
}

class _StaffEditorDialog extends StatefulWidget {
  final List<String> roles;
  final StaffMember? existing;
  const _StaffEditorDialog({required this.roles, this.existing});

  @override
  State<_StaffEditorDialog> createState() => _StaffEditorDialogState();
}

class _StaffEditorDialogState extends State<_StaffEditorDialog> {
  final name = TextEditingController();
  final contact = TextEditingController();
  late String role;

  // Availability editor: choose days via chips and one common time range for simplicity.
  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<String> selected = {};
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    role = widget.roles.first;
    if (widget.existing != null) {
      name.text = widget.existing!.name;
      contact.text = widget.existing!.contact;
      role = widget.existing!.role;
      // Best-effort parse: mark days present in the availability string.
      for (final d in days) {
        if (widget.existing!.availability.contains(d)) selected.add(d);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Staff' : 'Edit Staff'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: role,
                  isExpanded: true,
                  items: [
                    for (final r in widget.roles) DropdownMenuItem(value: r, child: Text(r)),
                  ],
                  onChanged: (v) => setState(() => role = v!),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(controller: contact, decoration: const InputDecoration(labelText: 'Contact')),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Availability', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final d in days)
                  FilterChip(
                    label: Text(d),
                    selected: selected.contains(d),
                    onSelected: (v) => setState(() {
                      if (v) {
                        selected.add(d);
                      } else {
                        selected.remove(d);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.schedule),
                  title: Text('Start: ${start.format(context)}'),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: start);
                    if (t != null) setState(() => start = t);
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.schedule),
                  title: Text('End: ${end.format(context)}'),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: end);
                    if (t != null) setState(() => end = t);
                  },
                ),
              ),
            ]),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final avail = selected.isEmpty
                ? '—'
                : selected.map((d) => '$d ${_fmt(start)}–${_fmt(end)}').join('; ');
            final result = StaffMember(
              name: name.text.trim(),
              role: role,
              contact: contact.text.trim(),
              availability: avail,
            );
            Navigator.pop(context, result);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

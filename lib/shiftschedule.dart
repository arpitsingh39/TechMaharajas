// lib/shiftschedule.dart — start/end, dynamic role counts, peak hours, generate + overflow-safe layout
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ShiftSchedulePage extends StatefulWidget {
  const ShiftSchedulePage({super.key});
  @override
  State<ShiftSchedulePage> createState() => _ShiftSchedulePageState();
}

class _ShiftSchedulePageState extends State<ShiftSchedulePage> with TickerProviderStateMixin {
  // Top-level time window
  TimeOfDay? startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? endTime   = const TimeOfDay(hour: 17, minute: 0);

  // Dynamic “No. of employees by role”
  final List<_RoleRow> roles = [ _RoleRow(role: 'Cashier', count: 2) ];

  // Dynamic “Peak hours” rows
  final List<_PeakRow> peaks = [ _PeakRow(role: 'Cashier', start: const TimeOfDay(hour: 12, minute: 0), end: const TimeOfDay(hour: 14, minute: 0)) ];

  // Date and state
  DateTime selectedDate = DateTime.now();
  bool _loading = false;
  String? _error;

  // Anim for preview
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Preview data
  List<ShiftData> shifts = [];

  static const String _base = 'https://studious-space-cod-7qjp49qj756fg74-5000.app.github.dev';
  static const String _path = '/api/schedule';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[900]);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)]),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView( // overflow-safe
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _headerCard(heading),
              const SizedBox(height: 16),
              _workingWindowCard(heading),
              const SizedBox(height: 16),

              // Responsive tables area
              LayoutBuilder(
                builder: (context, c) {
                  final isWide = c.maxWidth > 1000;
                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _rolesCard(heading)),
                        const SizedBox(width: 16),
                        Expanded(child: _peaksCard(heading)),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _rolesCard(heading),
                      const SizedBox(height: 16),
                      _peaksCard(heading),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // Timeline preview with fixed height
              SizedBox(
                height: 240,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardBox(),
                  child: Stack(
                    children: [
                      FadeTransition(opacity: _fadeAnimation, child: _timelinePreview()),
                      if (_error != null)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
                              child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 12)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Cards and sections

  Widget _headerCard(TextStyle heading) => Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardBox(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Shift Schedule', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey[900])),
              const SizedBox(height: 4),
              Text('Define hours, staffing by role, and peak-hours before generating', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            ]),
            Row(
              children: [
                _OutlinedPill(
                  onTap: () => _selectDate(context),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _loading ? null : _onGeneratePressed,
                    child: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Generate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _workingWindowCard(TextStyle heading) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardBox(),
        child: Row(
          children: [
            Text('Working window', style: heading),
            const Spacer(),
            _TimeField(
              label: 'Start time',
              value: startTime!,
              onPick: () async {
                final t = await showTimePicker(context: context, initialTime: startTime!);
                if (t != null) setState(() => startTime = t);
              },
            ),
            const SizedBox(width: 12),
            _TimeField(
              label: 'End time',
              value: endTime!,
              onPick: () async {
                final t = await showTimePicker(context: context, initialTime: endTime!);
                if (t != null) setState(() => endTime = t);
              },
            ),
          ],
        ),
      );

  Widget _rolesCard(TextStyle heading) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardBox(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('No. of employees by role', style: heading),
          const SizedBox(height: 8),
          Text('Add roles and how many staff are assigned to each role', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
          _RoleTable(
            rows: roles,
            onAdd: () => setState(() => roles.add(_RoleRow(role: '', count: 1))),
            onRemove: (i) => setState(() => roles.removeAt(i)),
            onChanged: (i, v) => setState(() => roles[i] = v),
          ),
        ]),
      );

  Widget _peaksCard(TextStyle heading) => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardBox(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Peak hours by role', style: heading),
          const SizedBox(height: 8),
          Text('Define multiple peak windows per role', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
          _PeakTable(
            rows: peaks,
            onAdd: () => setState(() => peaks.add(_PeakRow(role: '', start: const TimeOfDay(hour: 12, minute: 0), end: const TimeOfDay(hour: 13, minute: 0)))),
            onRemove: (i) => setState(() => peaks.removeAt(i)),
            onChanged: (i, v) => setState(() => peaks[i] = v),
          ),
        ]),
      );

  // Generate -> POST -> preview
  Future<void> _onGeneratePressed() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payload = _buildPayload();
      if (kDebugMode) print('Generate payload: ${jsonEncode(payload)}');

      final uri = Uri.parse('$_base$_path');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        print('POST $_path -> ${res.statusCode}');
        if (res.statusCode >= 400) print(res.body);
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Schedule API ${res.statusCode}');
      }

      final decoded = _safeDecode(res.body);
      final list = _extractList(decoded);
      final mapped = _mapShifts(list);
      setState(() => shifts = mapped);
      _fadeController.forward(from: 0);
    } catch (e) {
      setState(() => _error = 'Failed to generate schedule: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    String fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    final rolesJson = roles
        .where((r) => r.role.trim().isNotEmpty && r.count > 0)
        .map((r) => {'role': r.role.trim(), 'count': r.count})
        .toList();

    final peaksJson = peaks
        .where((p) => p.role.trim().isNotEmpty)
        .map((p) => {
              'role': p.role.trim(),
              'start': fmt(p.start),
              'end': fmt(p.end),
            })
        .toList();

    return {
      'date': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
      'start_time': fmt(startTime!),
      'end_time': fmt(endTime!),
      'staffing': rolesJson,
      'peak_hours': peaksJson,
    };
  }

  // Timeline preview
  Widget _timelinePreview() {
    if (shifts.isEmpty) {
      return Center(
        child: Text('Generated shifts will preview here after pressing Generate', style: TextStyle(color: Colors.grey[600])),
      );
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: shifts.length,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (_, i) {
        final s = shifts[i];
        return Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.employeeName, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(s.role, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
              const Spacer(),
              Text('${_fmt(s.startHour)} - ${_fmt(s.endHour)}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  BoxDecoration _cardBox() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2))],
      );

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  String _fmt(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  // Safe json decode helpers
  dynamic _safeDecode(String s) {
    try { return jsonDecode(s); } catch (_) {
      final i = s.indexOf('{'); return i >= 0 ? jsonDecode(s.substring(i)) : [];
    }
  }

  dynamic _extractList(dynamic json) {
    if (json is List) return json;
    if (json is Map) {
      for (final k in ['schedule', 'schedules', 'data', 'result', 'items']) {
        final v = json[k];
        if (v is List) return v;
      }
    }
    return [];
  }

  List<ShiftData> _mapShifts(dynamic listJson) {
    final list = (listJson is List) ? listJson : <dynamic>[];
    final out = <ShiftData>[];
    for (final e in list) {
      if (e is! Map) continue;
      final name = (e['employeeName'] ?? e['name'] ?? 'Employee').toString().trim();
      final role = (e['role'] ?? 'Staff').toString().trim();

      double start = 9.0, end = 17.0;
      if (e['startHour'] is num) start = (e['startHour'] as num).toDouble();
      if (e['endHour'] is num) end = (e['endHour'] as num).toDouble();
      if (e['start'] is String && e['end'] is String) {
        start = _parseHHmmToHour(e['start'] as String);
        end   = _parseHHmmToHour(e['end'] as String);
      }
      final rate = (e['hourlyRate'] is num) ? (e['hourlyRate'] as num).toDouble() : 0.0;
      final color = const Color(0xFF3B82F6);

      out.add(ShiftData(employeeName: name, role: role, startHour: start, endHour: end, hourlyRate: rate, color: color));
    }
    return out;
  }

  double _parseHHmmToHour(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 9.0;
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts[1]) ?? 0;
    return h + (m / 60.0);
  }
}

// UI helpers

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay value;
  final VoidCallback onPick;
  const _TimeField({required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    String fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time, size: 18),
            const SizedBox(width: 8),
            Text('$label: ${fmt(value)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _OutlinedPill extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _OutlinedPill({required this.child, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: child,
      ),
    );
  }
}

// Role table
class _RoleTable extends StatelessWidget {
  final List<_RoleRow> rows;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index, _RoleRow next) onChanged;

  const _RoleTable({required this.rows, required this.onAdd, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _tableHeader(['Role', 'Count', '']),
        const Divider(height: 1),
        ...rows.asMap().entries.map((e) {
          final i = e.key; final r = e.value;
          final roleCtrl = TextEditingController(text: r.role);
          final countCtrl = TextEditingController(text: r.count.toString());
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: roleCtrl,
                    decoration: const InputDecoration(hintText: 'e.g., Cashier', border: OutlineInputBorder()),
                    onChanged: (v) => onChanged(i, r.copyWith(role: v)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: countCtrl,
                    decoration: const InputDecoration(hintText: 'Count', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => onChanged(i, r.copyWith(count: int.tryParse(v) ?? r.count)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: rows.length == 1 ? null : () => onRemove(i),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add role')),
        ),
      ],
    );
  }

  Widget _tableHeader(List<String> cols) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(cols[0], style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: Text(cols[1], style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: Text(cols[2])),
        ],
      ),
    );
  }
}

// Peak hours table
class _PeakTable extends StatelessWidget {
  final List<_PeakRow> rows;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int index, _PeakRow next) onChanged;

  const _PeakTable({required this.rows, required this.onAdd, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    String fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Column(
      children: [
        _tableHeader(['Role', 'Start', 'End', '']),
        const Divider(height: 1),
        ...rows.asMap().entries.map((e) {
          final i = e.key; final r = e.value;
          final roleCtrl = TextEditingController(text: r.role);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: roleCtrl,
                    decoration: const InputDecoration(hintText: 'e.g., Cashier', border: OutlineInputBorder()),
                    onChanged: (v) => onChanged(i, r.copyWith(role: v)),
                  ),
                ),
                const SizedBox(width: 8),
                _timeButton(
                  label: fmt(r.start),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: r.start);
                    if (t != null) onChanged(i, r.copyWith(start: t));
                  },
                ),
                const SizedBox(width: 8),
                _timeButton(
                  label: fmt(r.end),
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: r.end);
                    if (t != null) onChanged(i, r.copyWith(end: t));
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: rows.length == 1 ? null : () => onRemove(i),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add peak hours')),
        ),
      ],
    );
  }

  Widget _timeButton({required String label, required VoidCallback onTap}) {
    return SizedBox(
      width: 120,
      height: 48,
      child: OutlinedButton(
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

  Widget _tableHeader(List<String> cols) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(cols[0], style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: Text(cols[1], style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: Text(cols[2], style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          SizedBox(width: 40, child: Text(cols[3])),
        ],
      ),
    );
  }
}

// Data holders for UI tables
class _RoleRow {
  final String role;
  final int count;
  _RoleRow({required this.role, required this.count});
  _RoleRow copyWith({String? role, int? count}) => _RoleRow(role: role ?? this.role, count: count ?? this.count);
}

class _PeakRow {
  final String role;
  final TimeOfDay start;
  final TimeOfDay end;
  _PeakRow({required this.role, required this.start, required this.end});
  _PeakRow copyWith({String? role, TimeOfDay? start, TimeOfDay? end}) =>
      _PeakRow(role: role ?? this.role, start: start ?? this.start, end: end ?? this.end);
}

// Shift preview model
class ShiftData {
  final String employeeName;
  final String role;
  final double startHour;
  final double endHour;
  final double hourlyRate;
  final Color color;
  ShiftData({required this.employeeName, required this.role, required this.startHour, required this.endHour, required this.hourlyRate, required this.color});
}

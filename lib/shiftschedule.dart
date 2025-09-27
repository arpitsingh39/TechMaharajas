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
  Map<String, dynamic>? fairnessSummary;
  Map<String, dynamic>? unmetDemand;
  Map<String, dynamic>? scheduleByRoleAssignments;
  Map<String, dynamic>? rawApiResponse;
  bool approved = false;

  static const String _base = 'https://techmaharajas.onrender.com';
  static const String _path = '/api/solve';

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
              const SizedBox(height: 16),
              _metaSection(),
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
      if (kDebugMode) print('Response: $decoded');
      rawApiResponse = decoded is Map ? Map<String, dynamic>.from(decoded) : null;
      // Parse API response into ShiftData entries (supports by_day and schedule.by_role_assignments)
      final mapped = _parseApiResponse(decoded);
      // Extract additional metadata (fairness, unmet, schedule.by_role_assignments)
      _parseAndStoreApi(decoded);
      setState(() {
        shifts = mapped;
        approved = false; // new generation resets approval
      });
      _fadeController.forward(from: 0);
    } catch (e) {
      setState(() => _error = 'Failed to generate schedule: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    String fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    // Build roles as an object map { roleName: count } to satisfy server validation
    final Map<String, int> rolesMap = {};
    for (final r in roles) {
      final name = r.role.trim();
      if (name.isNotEmpty && r.count > 0) {
        rolesMap[name] = r.count;
      }
    }

  // Day label and weekday (1=Mon..7=Sun in Dart)
  const weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final dayLabel = weekdayNames[(selectedDate.weekday - 1) % 7];

  // Keep a list-shaped staffing object too for backward compatibility; include weekday metadata
  final staffingList = rolesMap.entries
    .map((e) => {
        'role': e.key,
        'count': e.value,
        'weekday': selectedDate.weekday,
        'day_label': dayLabel,
      })
    .toList();

    // Peaks / peak hours
  final peaksJson = peaks
    .where((p) => p.role.trim().isNotEmpty)
    .map((p) => {
        'role': p.role.trim(),
        'start': fmt(p.start),
        'end': fmt(p.end),
        'weekday': selectedDate.weekday,
        'day_label': dayLabel,
      })
    .toList();

    // Validation: roles must be non-empty object
    if (rolesMap.isEmpty) {
      throw Exception('validation_failed: roles must be a non-empty object {role:int}');
    }

  // Day label and weekday (already computed above)

    // shop_id is required by API; use a default of 1 unless your app provides a different value.
    const int shopId = 1;

    return {
      'shop_id': shopId,
      'date': '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
      // API expects open/close as HH:MM strings
      'open': fmt(startTime!),
      'close': fmt(endTime!),
      // keep old keys for compatibility
      'start_time': fmt(startTime!),
      'end_time': fmt(endTime!),
  // weekday metadata (top-level)
  'weekday': weekdayNames[selectedDate.weekday-1],
  'day_label': dayLabel,
      // roles as object and array (object required by validation)
      'roles': rolesMap,
      'staffing': staffingList,
      'peak_hours': peaksJson,
    };
  }

  // Timeline preview: grouped per-employee horizontal bars between working window
  Widget _timelinePreview() {
    if (shifts.isEmpty) {
      return Center(
        child: Text('Generated shifts will preview here after pressing Generate', style: TextStyle(color: Colors.grey[600])),
      );
    }

    double tdFromTimeOfDay(TimeOfDay t) => t.hour + t.minute / 60.0;
    final windowStart = tdFromTimeOfDay(startTime!);
    final windowEnd = tdFromTimeOfDay(endTime!);
    var windowSpan = windowEnd - windowStart;
    if (windowSpan <= 0) windowSpan = 24.0;

    // Group shifts by employee
    final Map<String, List<ShiftData>> byEmp = {};
    for (final s in shifts) {
      byEmp.putIfAbsent(s.employeeName, () => []).add(s);
    }
    final employees = byEmp.keys.toList()..sort();

    // Time labels (every 2 hours approx)
    final labels = <double>[];
    final step = (windowSpan / 6).clamp(1.0, 4.0);
    for (var t = windowStart; t <= windowEnd; t += step) labels.add(t);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // time ruler
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: LayoutBuilder(builder: (context, c) {
            return Row(
              children: [
                const SizedBox(width: 140),
                Expanded(
                  child: Stack(
                    children: [
                      Container(height: 24, color: Colors.transparent),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: labels.map((t) => Text(_fmt(t), style: const TextStyle(fontSize: 11, color: Colors.grey))).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),

        // employee rows
        Expanded(
          child: ListView.separated(
            itemCount: employees.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final name = employees[idx];
              final items = byEmp[name]!;
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    SizedBox(
                      width: 140,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(items.map((e) => e.role).where((r) => r.isNotEmpty).join(', '), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(builder: (context, c) {
                        return SizedBox(
                          height: 48,
                          child: Stack(children: [
                            // background timeline line
                            Positioned.fill(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 20),
                                height: 8,
                                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                            // shift bars
                            for (final s in items)
                              if (s.endHour > s.startHour)
                                Positioned(
                                  left: ((s.startHour - windowStart) / windowSpan).clamp(0.0, 1.0) * c.maxWidth,
                                  width: (((s.endHour - s.startHour) / windowSpan).clamp(0.0, 1.0)) * c.maxWidth,
                                  top: 6,
                                  bottom: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(color: s.color.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
                                    child: Row(children: [
                                      Expanded(child: Text('${_fmt(s.startHour)} - ${_fmt(s.endHour)}', style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                    ]),
                                  ),
                                ),
                          ]),
                        );
                      }),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _metaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FilledButton(
              onPressed: shifts.isEmpty || approved
                  ? null
                  : () {
                      // Admin approves schedule
                      setState(() => approved = true);
                    },
              child: const Text('Approve Schedule'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: shifts.isEmpty || approved
                  ? null
                  : () {
                      // Edit mode: allow edits - here we just toggle approved false to simulate
                      setState(() => approved = false);
                    },
              child: const Text('Edit Slots'),
            ),
            const SizedBox(width: 12),
            Text(approved ? 'Status: Approved' : 'Status: Draft', style: TextStyle(fontWeight: FontWeight.w600, color: approved ? Colors.green[700] : Colors.orange[700])),
          ],
        ),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _fairnessCard()),
          const SizedBox(width: 12),
          Expanded(child: _unmetCard()),
        ]),
        const SizedBox(height: 12),
        _backupsCard(),
      ],
    );
  }

  Widget _fairnessCard() {
    if (fairnessSummary == null) return _infoCard('Fairness', 'No fairness data available');
    final cum = fairnessSummary!['cum_hours'] ?? {};
    final empHours = fairnessSummary!['emp_hours_today'] ?? {};
    final used = fairnessSummary!['employees_used'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Fairness Summary', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Employees used: $used'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: cum.keys.map<Widget>((k) {
            final c = cum[k];
            final today = empHours[k] ?? 0;
            return Chip(label: Text('$k: total ${c ?? 0}, today ${today}'));
          }).toList(),
        ),
      ]),
    );
  }

  Widget _unmetCard() {
    if (unmetDemand == null) return _infoCard('Unmet Demand', 'No unmet/demand info');
    // unmetDemand structure usually: { daykey: { role: [ {start,end,needed} ] } }
  final dayKey = (rawApiResponse != null && rawApiResponse!['day_label'] != null) ? rawApiResponse!['day_label'].toString().toLowerCase() : '';
    final dayMap = (unmetDemand![dayKey] is Map) ? unmetDemand![dayKey] as Map : (unmetDemand!.isNotEmpty ? unmetDemand!.values.first : null);
    if (dayMap == null) return _infoCard('Unmet Demand', 'None');
    final items = <Widget>[];
    dayMap.forEach((role, segments) {
      if (segments is List) {
        for (final s in segments) {
          final needed = s['needed'] ?? s['count'] ?? '?';
          items.add(Text('$role: ${s['start']} - ${s['end']} needed: $needed'));
        }
      }
    });
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Unmet / Non-decided Demand', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (items.isEmpty) const Text('None') else ...items,
      ]),
    );
  }

  Widget _backupsCard() {
    if (scheduleByRoleAssignments == null) return _infoCard('Backups', 'No backup info available');
    // show simple list of backups for today's day
  final dayKey = (rawApiResponse != null && rawApiResponse!['day_label'] != null) ? rawApiResponse!['day_label'].toString().toLowerCase() : '';
    final dayMap = scheduleByRoleAssignments![dayKey] is Map ? scheduleByRoleAssignments![dayKey] as Map : (scheduleByRoleAssignments!.isNotEmpty ? scheduleByRoleAssignments!.values.first : null);
    final rows = <Widget>[];
    if (dayMap is Map) {
      dayMap.forEach((role, segments) {
        if (segments is List) {
          for (final seg in segments) {
            final backups = seg['backups'];
            if (backups is List && backups.isNotEmpty) {
              rows.add(Text('$role backups: ${backups.map((b) => b['name'] ?? b['id']).join(', ')}'));
            }
          }
        }
      });
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Backups / Info', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (rows.isEmpty) const Text('No backups reported') else ...rows,
      ]),
    );
  }

  Widget _infoCard(String title, String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardBox(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8), Text(text)]),
      );

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

  // ...existing code...

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

  // Parse a full API response (map) into ShiftData list. Handles both 'by_day'->day->employees
  // and 'schedule'->'by_role_assignments' formats.
  List<ShiftData> _parseApiResponse(dynamic decoded) {
    final out = <ShiftData>[];
    if (decoded is Map) {
      // determine day key (lowercase)
      String dayKey = '';
      if (decoded['day_label'] is String) dayKey = decoded['day_label'].toString().toLowerCase();
      if (dayKey.isEmpty) {
        const weekdayNames = ['monday','tuesday','wednesday','thursday','friday','saturday','sunday'];
        dayKey = weekdayNames[(selectedDate.weekday - 1) % 7];
      }

      // 1) Try by_day -> dayKey -> employees
      try {
        final byDay = decoded['by_day'];
        if (byDay is Map && byDay[dayKey] is Map) {
          final employees = byDay[dayKey]['employees'];
          if (employees is Map) {
            employees.forEach((name, segments) {
              if (segments is List) {
                for (final seg in segments) {
                  if (seg is Map && seg['start'] is String && seg['end'] is String) {
                    final start = _parseHHmmToHour(seg['start'] as String);
                    final end = _parseHHmmToHour(seg['end'] as String);
                    out.add(ShiftData(
                      employeeName: name.toString(),
                      role: '',
                      startHour: start,
                      endHour: end,
                      hourlyRate: 0.0,
                      color: _colorForName(name.toString()),
                    ));
                  }
                }
              }
            });
            if (out.isNotEmpty) return out;
          }
        }
      } catch (_) {}

      // 2) Try schedule -> by_role_assignments -> dayKey
      try {
        final bra = decoded['schedule']?['by_role_assignments']?[dayKey];
        if (bra is Map) {
          bra.forEach((role, segments) {
            if (segments is List) {
              for (final seg in segments) {
                final startStr = seg['start'];
                final endStr = seg['end'];
                final employeesList = seg['employees'];
                if (startStr is String && endStr is String && employeesList is List) {
                  final start = _parseHHmmToHour(startStr);
                  final end = _parseHHmmToHour(endStr);
                  for (final en in employeesList) {
                    out.add(ShiftData(
                      employeeName: en.toString(),
                      role: role.toString(),
                      startHour: start,
                      endHour: end,
                      hourlyRate: 0.0,
                      color: _colorForName(en.toString()),
                    ));
                  }
                }
              }
            }
          });
          if (out.isNotEmpty) return out;
        }
      } catch (_) {}
    }

    // Fallback: if response contains a list-like structure, reuse existing mapper
    if (decoded is List) return _mapShifts(decoded);
    return out;
  }

  Color _colorForName(String name) {
    final h = name.hashCode;
    final r = (h & 0xFF0000) >> 16;
    final g = (h & 0x00FF00) >> 8;
    final b = (h & 0x0000FF);
    // brighten a bit
    int br(int v) => ((v + 120) % 200) + 30;
    return Color.fromARGB(255, br(r), br(g), br(b));
  }

  void _parseAndStoreApi(dynamic decoded) {
    try {
      if (decoded is! Map) return;
      fairnessSummary = decoded['fairness_summary'] is Map ? Map<String, dynamic>.from(decoded['fairness_summary']) : null;
      unmetDemand = decoded['unmet_demand'] is Map ? Map<String, dynamic>.from(decoded['unmet_demand']) : null;
      scheduleByRoleAssignments = decoded['schedule'] is Map && decoded['schedule']['by_role_assignments'] is Map
          ? Map<String, dynamic>.from(decoded['schedule']['by_role_assignments'])
          : null;
    } catch (_) {
      fairnessSummary = null;
      unmetDemand = null;
      scheduleByRoleAssignments = null;
    }
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
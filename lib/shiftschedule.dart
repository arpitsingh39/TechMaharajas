// lib/shift schedule.dart — schedule fetch with multi-variant fallback to avoid 400s
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
  DateTime selectedDate = DateTime.now();

  // Show timeline immediately (keeps previous UX)
  bool isGenerated = true;

  bool _loading = false;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<ShiftData> shifts = [
    ShiftData(employeeName: 'Alex Johnson', role: 'Cashier', startHour: 9.0, endHour: 17.0, hourlyRate: 15.0, color: const Color(0xFF3B82F6)),
    ShiftData(employeeName: 'Maria Garcia', role: 'Server', startHour: 10.0, endHour: 18.0, hourlyRate: 14.5, color: const Color(0xFF10B981)),
  ];

  static const String _base = 'https://studious-space-cod-7qjp49qj756fg74-5000.app.github.dev';
  static const String _path = '/api/schedule';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _silentRefresh();
  }

  Future<void> _silentRefresh() async {
    try {
      final fetched = await _fetchSchedule(selectedDate);
      if (!mounted || fetched.isEmpty) return;
      setState(() => shifts = fetched);
      _fadeController.forward(from: 0);
    } catch (_) {}
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)]),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2)),
            ]),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Shift Schedule', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey[900], letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Manage and approve daily shift assignments', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              ]),
              Row(children: [
                // Date
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                  ),
                ),
                const SizedBox(width: 16),
                // Generate
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onGeneratePressed,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (_loading)
                            const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          else
                            const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(_loading ? 'Generating...' : 'Generate Schedule',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // Timeline card
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2)),
              ]),
              child: Stack(children: [
                FadeTransition(opacity: _fadeAnimation, child: _buildTimeline()),
                if (_error != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red[200]!)),
                        child: Text(_error!, style: TextStyle(color: Colors.red[700], fontSize: 12)),
                      ),
                    ),
                  ),
              ]),
            ),
          ),

          const SizedBox(height: 20),

          // Approve
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 6))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _approveSchedule,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Approve Schedule', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildTimeline() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Daily Shift Timeline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[900])),
        const SizedBox(height: 8),
        Text('Visual representation of employee shifts and working hours', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const SizedBox(height: 24),

        // Hours
        SizedBox(
          height: 40,
          child: Row(children: [
            const SizedBox(width: 150),
            Expanded(
              child: Row(children: List.generate(12, (i) {
                final h = 8 + i;
                return Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey[200]!, width: 1))),
                    child: Text('${h.toString().padLeft(2, '0')}:00', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600])),
                  ),
                );
              })),
            ),
          ]),
        ),

        const Divider(color: Colors.grey),

        // Rows
        Expanded(
          child: ListView.builder(
            itemCount: shifts.length,
            itemBuilder: (_, i) => _row(shifts[i]),
          ),
        ),
      ]),
    );
  }

  Widget _row(ShiftData s) {
    return Container(
      height: 80, margin: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        SizedBox(
          width: 150,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(s.employeeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: s.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(s.role, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: s.color)),
            ),
          ]),
        ),
        Expanded(
          child: Container(
            height: 60,
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              final left = ((s.startHour - 8) / 12).clamp(0.0, 1.0) * w;
              final width = ((s.endHour - s.startHour) / 12).clamp(0.0, 1.0) * w;
              final hours = (s.endHour - s.startHour).clamp(0.0, 24.0);
              final pay = hours * s.hourlyRate;

              return Stack(children: [
                Row(children: List.generate(12, (i) => Expanded(child: Container(decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.grey[200]!, width: i == 0 ? 0 : 1))))))),
                Positioned(
                  left: left, top: 8,
                  child: Container(
                    width: width, height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [s.color, s.color.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: s.color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${_fmt(s.startHour)} - ${_fmt(s.endHour)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        Text('${hours.toStringAsFixed(1)}h • ₹${pay.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w400)),
                      ]),
                    ),
                  ),
                ),
              ]);
            }),
          ),
        ),
      ]),
    );
  }

  String _fmt(double h) {
    final hh = h.floor();
    final mm = ((h - hh) * 60).round();
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  Future<void> _onGeneratePressed() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fetched = await _fetchSchedule(selectedDate);
      if (!mounted) return;
      if (fetched.isEmpty) {
        setState(() => _error = 'No shifts available for the selected date.');
      } else {
        setState(() => shifts = fetched);
        _fadeController.forward(from: 0);
      }
    } catch (e) {
      if (kDebugMode) print('Schedule error: $e');
      if (!mounted) return;
      setState(() => _error = 'Failed to load schedule. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _approveSchedule() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 8),
          Text('Schedule approved for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
        ]),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: const DatePickerThemeData(backgroundColor: Colors.white, surfaceTintColor: Color(0xFF3B82F6)),
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        _error = null;
      });
      _silentRefresh();
    }
  }

  // Try the most likely shapes to avoid HTTP 400s
  

// Follow-up read call (adjust path/query to your backend)
Future<List<ShiftData>> _fetchSchedule(DateTime date) async {
  const int shopId = 1;
  const int staffId = 1;
  const int roleId = 1;

  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yy = (date.year % 100).toString().padLeft(2, '0'); // DD/MM/YY
  final dDmyShort = '$dd/$mm/$yy';

  final List<String> shiftsSpec = ['09:00-17:00'];

  final payload = {
    'shop_id': shopId,
    'staff_id': staffId,
    'role_id': roleId,
    'date': dDmyShort,
    'shifts': shiftsSpec,
  };

  final uri = Uri.parse('$_base$_path');
  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode(payload),
  );

  if (kDebugMode) {
    print('POST /api/schedule status ${res.statusCode}');
    if (res.statusCode >= 400) {
      print('Server says: ${res.body}');
    }
  }

  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Schedule API ${res.statusCode}');
  }

  // Prefer server response items
  final decoded = _safeDecode(res.body);
  final list = _extractList(decoded);
  final mapped = _mapShifts(list);
  if (mapped.isNotEmpty) return mapped;

  // Provisional fallback based on what we just posted
  final fallback = <ShiftData>[];
  for (final spec in shiftsSpec) {
    final parts = spec.split('-');
    double start = 9.0, end = 17.0;
    if (parts.length == 2) {
      start = _parseHHmmToHour(parts[0]);
      end = _parseHHmmToHour(parts[1]);
    }
    fallback.add(
      ShiftData(
        employeeName: 'Staff #$staffId',
        role: 'Role #$roleId',
        startHour: start,
        endHour: end,
        hourlyRate: 0.0,
        color: const Color(0xFF3B82F6),
      ),
    );
  }
  return fallback;
}
double _parseHHmmToHour(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return 9.0;
  final h = int.tryParse(parts[0]) ?? 9;
  final m = int.tryParse(parts[1]) ?? 0;
  return h + (m / 60.0);
}






  dynamic _safeDecode(String s) {
  try {
    return jsonDecode(s);
  } catch (_) {
    final i = s.indexOf('{');
    return i >= 0 ? jsonDecode(s.substring(i)) : [];
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
      end = _parseHHmmToHour(e['end'] as String);
    }

    final rate = (e['hourlyRate'] is num) ? (e['hourlyRate'] as num).toDouble() : 0.0;
    final color = _parseColor(e['color']);

    out.add(ShiftData(
      employeeName: name,
      role: role,
      startHour: start,
      endHour: end,
      hourlyRate: rate,
      color: color,
    ));
  }
  return out;
}

Color _parseColor(dynamic v) {
  if (v == null) return const Color(0xFF3B82F6);
  var s = v.toString().trim();
  if (s.startsWith('#')) s = s.substring(1);
  s = s.replaceAll(RegExp(r'^0x', caseSensitive: false), '');
  if (s.length == 6) s = 'FF$s';
  final i = int.tryParse(s, radix: 16);
  if (i != null) return Color(i);
  switch (v.toString().toLowerCase()) {
    case 'blue':
      return const Color(0xFF3B82F6);
    case 'green':
      return const Color(0xFF10B981);
    case 'amber':
      return const Color(0xFFF59E0B);
    case 'purple':
      return const Color(0xFF8B5CF6);
    case 'red':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF3B82F6);
  }
}

}

class ShiftData {
  final String employeeName;
  final String role;
  final double startHour;
  final double endHour;
  final double hourlyRate;
  final Color color;
  ShiftData({required this.employeeName, required this.role, required this.startHour, required this.endHour, required this.hourlyRate, required this.color});
}

// lib/Dashboard page.dart — Dashboard with inline date picker in Daily Hours card,
// centered PieChart with bottom legend, extra spacing, and a Weekly Hours Trend line chart
// wired to backend APIs for pie, bar, and line data without changing UI/logic.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

class DashboardShell extends StatelessWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final menu = <({String label, IconData icon, String path})>[
      (label: 'Dashboard', icon: Icons.space_dashboard, path: '/dashboard'),
      (label: 'Roles', icon: Icons.store, path: '/staff/staff_setup'),
      (label: 'Staff', icon: Icons.person, path: '/staff/staff_management'),
      (label: 'Shift Schedule', icon: Icons.event_note, path: '/shiftschedule'),
      (label: 'Reports / Payroll', icon: Icons.bar_chart, path: '/reportpage'),
    ];

    final currentPath = GoRouterState.of(context).uri.path;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top navigation bar (replaces left sidebar)
          SafeArea(
            bottom: false,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2231), Color(0xFF0B1A27)],
                ),
              ),
              child: Row(
                children: [
                  // Logo
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset('assets/app_logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  // Horizontal menu
                  for (final m in menu)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: TextButton.icon(
                        onPressed: () => context.go(m.path),
                        icon: Icon(
                          m.icon,
                          size: 18,
                          color: currentPath.startsWith(m.path)
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.85),
                        ),
                        label: Text(
                          m.label,
                          style: TextStyle(
                            color: currentPath.startsWith(m.path)
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                    ),
                  const Spacer(),
                  // Language selector (reusing existing chip)
                  SizedBox(width: 180, child: _SidebarLanguageChip()),
                  const SizedBox(width: 8),
                  // Logout
                  SizedBox(
                    height: 40,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        AppState.of(context).signOut();
                        context.go('/');
                      },
                      child: const Row(
                        children: [
                          Icon(Icons.logout, size: 18),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chatbot button on the far right of the top bar
                  FilledButton.icon(
                    onPressed: () => context.go('/chatbot'),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Chatbot'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime selectedDate = DateTime.now();

  // State fed from APIs (initialized with the same demo values as before).
  Map<String, double> dailyHours = {
    'Alice': 8.5,
    'Bob': 7.0,
    'Charlie': 9.5,
    'Diana': 6.0,
    'Ethan': 8.0,
  };

  Map<String, int> roleDistribution = {
    'Cashier': 10,
    'Cleaner': 5,
    'Chef': 7,
    'Server': 8,
    'Manager': 3,
  };

  Map<String, double> weeklyDeviations = {
    'Monday': 2.0,
    'Tuesday': -1.0,
    'Wednesday': 0.0,
    'Thursday': 3.0,
    'Friday': -2.0,
    'Saturday': 1.0,
  };

  Map<String, double> weeklyHours = {
    'Mon': 8.0,
    'Tue': 6.5,
    'Wed': 9.0,
    'Thu': 7.0,
    'Fri': 8.5,
    'Sat': 5.0,
    'Sun': 0.0,
  };

  bool _loadingPie = false;
  bool _loadingBar = false;
  bool _loadingLine = false;

  @override
  void initState() {
    super.initState();
    _refreshAllForDate(selectedDate);
  }

  Future<void> _refreshAllForDate(DateTime date) async {
    await Future.wait([
      _fetchPieChart(),
      _fetchBarChart(date),
      _fetchLineChart(date),
    ]);
  }

  // BASE URL
  static const String _base =
      'https://techmaharajas.onrender.com';

  // GET /api/piechart -> [{label, value}]
  Future<void> _fetchPieChart() async {
    if (_loadingPie) return;
    setState(() => _loadingPie = true);
    try {
      final uri = Uri.parse('$_base/api/piechart');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final mapped = _mapPieResponse(data);
        if (mapped.isNotEmpty) {
          setState(() => roleDistribution = mapped);
        }
      }
    } catch (_) {
      // keep last known values
    } finally {
      if (mounted) setState(() => _loadingPie = false);
    }
  }

  // GET /api/barchart?date=YYYY-MM-DD -> [{name, hours}]
  Future<void> _fetchBarChart(DateTime date) async {
    if (_loadingBar) return;
    setState(() => _loadingBar = true);
    try {
      final d = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final uri = Uri.parse('$_base/api/barchart?date=$d');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final mapped = _mapBarResponse(data);
        if (mapped.isNotEmpty) {
          setState(() => dailyHours = mapped);
        }
      }
    } catch (_) {
      // keep last known values
    } finally {
      if (mounted) setState(() => _loadingBar = false);
    }
  }

  // GET /api/linechart?weekOf=YYYY-MM-DD -> {
  //   weeklyHours:[{day:'Mon',hours:8.0},...],
  //   weeklyDeviation:[{day:'Monday',deviation:2.0},...]
  // }
  Future<void> _fetchLineChart(DateTime date) async {
    if (_loadingLine) return;
    setState(() => _loadingLine = true);
    try {
      final d = '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final uri = Uri.parse('$_base/api/linechart?weekOf=$d');
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final mappedHours = _mapLineHours(data);
        final mappedDev = _mapLineDeviation(data);
        setState(() {
          if (mappedHours.isNotEmpty) weeklyHours = mappedHours;
          if (mappedDev.isNotEmpty) weeklyDeviations = mappedDev;
        });
      }
    } catch (_) {
      // keep last known values
    } finally {
      if (mounted) setState(() => _loadingLine = false);
    }
  }

  // Mappers (adjust keys if backend differs)
  Map<String, int> _mapPieResponse(dynamic json) {
    if (json is List) {
      final out = <String, int>{};
      for (final e in json) {
        final label = e['label']?.toString();
        final v = e['value'];
        if (label != null && v is num) {
          out[label] = v.toInt();
        }
      }
      return out;
    }
    return {};
  }

  Map<String, double> _mapBarResponse(dynamic json) {
    if (json is List) {
      final out = <String, double>{};
      for (final e in json) {
        final name = e['name']?.toString();
        final v = e['hours'];
        if (name != null && v is num) {
          out[name] = v.toDouble();
        }
      }
      return out;
    }
    return {};
  }

  Map<String, double> _mapLineHours(dynamic json) {
    final out = <String, double>{};
    final list = (json is Map) ? json['weeklyHours'] : null;
    if (list is List) {
      for (final e in list) {
        final day = e['day']?.toString(); // Mon..Sun
        final v = e['hours'];
        if (day != null && v is num) out[day] = v.toDouble();
      }
    }
    return out;
  }

  Map<String, double> _mapLineDeviation(dynamic json) {
    final out = <String, double>{};
    final list = (json is Map) ? json['weeklyDeviation'] : null;
    if (list is List) {
      for (final e in list) {
        final day = e['day']?.toString(); // Monday..Sunday
        final v = e['deviation'];
        if (day != null && v is num) out[day] = v.toDouble();
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title at left, Chatbot button at right on the same line
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Workforce Analytics Dashboard',
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/chatbot'),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Chatbot'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Top Row: Daily Hours + Role Distribution
            Row(
              children: [
                // Daily Hours with inline date picker
                Expanded(
                  flex: 2,
                  child: _buildChartCard(
                    title: 'Daily Work Hours by Employee',
                    subtitle:
                        'Hours worked on ${selectedDate.day}/${selectedDate.month}',
                    chart: _buildDailyHoursChart(),
                    showInlineDatePicker: true,
                    height: 300,
                  ),
                ),
                const SizedBox(width: 20),
                // Role Distribution
                Expanded(
                  flex: 1,
                  child: _buildChartCard(
                    title: 'Staff Distribution by Role',
                    subtitle: '',
                    chart: _buildRoleDistributionCentered(),
                    height: 300,
                    hideChartSubtitle: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Weekly Deviation (left) + Weekly Hours Line (right)
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: _buildChartCard(
                    title: 'Weekly Hours Deviation Analysis',
                    subtitle: 'Daily deviation from target hours (Target: 10 hours)',
                    chart: _buildWeeklyDeviationChart(),
                    height: 280,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: _buildChartCard(
                    title: 'Weekly Hours Trend',
                    subtitle: 'Hours per day for the selected week',
                    chart: _buildWeeklyHoursLineChart(),
                    height: 280,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Bottom: Alerts & Summary
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildAlertSection()),
                const SizedBox(width: 20),
                Expanded(child: _buildSummarySection()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget chart,
    double? height,
    bool showInlineDatePicker = false,
    bool hideChartSubtitle = false,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with title and optional date picker
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
              if (showInlineDatePicker)
                _InlineDateButton(
                  date: selectedDate,
                  onTap: () async {
                    await _selectDate(context);
                    _fetchBarChart(selectedDate);
                    _fetchLineChart(selectedDate);
                  },
                ),
            ],
          ),
          if (!hideChartSubtitle) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: chart),
                if (_loadingPie && title.contains('Distribution'))
                  const _MiniLoader(),
                if (_loadingBar && title.contains('Daily Work Hours'))
                  const _MiniLoader(),
                if (_loadingLine &&
                    (title.contains('Trend') || title.contains('Deviation')))
                  const _MiniLoader(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyHoursChart() {
    final entries = dailyHours.entries.toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (entries
                    .map((e) => e.value)
                    .fold<double>(0, (p, c) => c > p ? c : p) +
                2)
            .clamp(6, 16)
            .toDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF3B82F6),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final idx = group.x.toInt();
              if (idx < 0 || idx >= entries.length) return null;
              final employee = entries[idx].key;
              return BarTooltipItem(
                '$employee\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                    text: '${rod.toY.toStringAsFixed(1)} hours',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < entries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      entries[value.toInt()].key,
                      style:
                          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}h',
                  style: const TextStyle(fontSize: 12),
                );
              },
              reservedSize: 30,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[200]!,
              strokeWidth: 1,
            );
          },
        ),
        barGroups: entries
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final hours = entry.value.value;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: hours,
                    color: const Color(0xFF3B82F6),
                    width: 24,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            })
            .toList(),
      ),
    );
  }

  // Centered pie chart with legend at the bottom
  Widget _buildRoleDistributionCentered() {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];
    final entries = roleDistribution.entries.toList();
    final total = roleDistribution.values.fold<int>(0, (a, b) => a + b);

    return Column(
      children: [
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(touchCallback: (event, response) {}),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: entries.asMap().entries.map((e) {
                    final index = e.key;
                    final count = e.value.value;
                    final percentage = total == 0 ? 0.0 : (count / total) * 100;
                    return PieChartSectionData(
                      color: colors[index % colors.length],
                      value: count.toDouble(),
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 60,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.center,
          child: Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final e in entries.asMap().entries)
                _LegendItem(
                  color: colors[e.key % colors.length],
                  label: e.value.key,
                  valueText: e.value.value.toString(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyDeviationChart() {
    final entries = weeklyDeviations.entries.toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 6,
        minY: -4,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final i = group.x.toInt();
              if (i < 0 || i >= entries.length) return null;
              final day = entries[i].key;
              final deviation = rod.toY;
              final prefix = deviation > 0 ? '+' : '';
              return BarTooltipItem(
                '$day\n$prefix${deviation.toStringAsFixed(1)} hours',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < entries.length) {
                  final day = entries[i].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      day.substring(0, 3),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}h',
                  style: const TextStyle(fontSize: 12),
                );
              },
              reservedSize: 30,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: value == 0 ? const Color(0x42000000) : Colors.grey[200]!,
              strokeWidth: value == 0 ? 2 : 1,
            );
          },
        ),
        barGroups: entries
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final deviation = entry.value.value;
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    fromY: 0,
                    toY: deviation,
                    color: deviation >= 0
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF4ECDC4),
                    width: 28,
                    borderRadius: BorderRadius.vertical(
                      top:
                          deviation >= 0 ? const Radius.circular(4) : Radius.zero,
                      bottom:
                          deviation < 0 ? const Radius.circular(4) : Radius.zero,
                    ),
                  ),
                ],
              );
            })
            .toList(),
      ),
    );
  }

  // Weekly hours line chart (X: weekday only, Y: hours)
  Widget _buildWeeklyHoursLineChart() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final List<FlSpot> spots = List<FlSpot>.generate(
      7,
      (i) => FlSpot(i.toDouble(), weeklyHours[days[i]] ?? 0.0),
    );

    double peak = 0;
    for (final v in weeklyHours.values) {
      if (v > peak) peak = v;
    }
    final double maxY = (peak + 2).clamp(6, 16).toDouble();

    String weekdayLabel(double x) {
      final idx = x.round();
      if (idx < 0 || idx >= days.length) return '';
      return days[idx];
    }

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey[200]!, strokeWidth: 1),
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final label = weekdayLabel(value);
                if (label.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 2,
              getTitlesWidget: (value, meta) =>
                  Text('${value.toInt()}h', style: const TextStyle(fontSize: 10)),
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF3B82F6),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 3.5,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: const Color(0xFF3B82F6),
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF3B82F6).withOpacity(0.12),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((ts) {
                final label = weekdayLabel(ts.x);
                return LineTooltipItem(
                  label.isEmpty ? '' : '$label\n',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: '${ts.y.toStringAsFixed(1)} hours',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAlertSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange[600], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Alerts & Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertItem(
            Icons.people_outline,
            'Staffing Alert',
            'Only 15 employees assigned this week. Consider adding 3 more staff members.',
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            Icons.schedule_outlined,
            'Overtime Alert',
            'Diana has worked 45 hours this week, exceeding the 40-hour limit.',
            Colors.red,
          ),
          const SizedBox(height: 12),
          _buildAlertItem(
            Icons.trending_down,
            'Low Coverage',
            'Weekend coverage is below optimal. Schedule more staff for Sat-Sun.',
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(
      IconData icon, String title, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: Colors.blue[600], size: 24),
              const SizedBox(width: 8),
              const Text(
                'Weekly Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryItem('Total Staff', '33', Icons.people, Colors.blue),
          _buildSummaryItem(
              'Hours This Week', '1,245', Icons.schedule, const Color(0xFF2E7D32)),
          _buildSummaryItem(
              'Average Hours/Day', '8.2', Icons.trending_up, Colors.orange),
          _buildSummaryItem(
              'Efficiency Score', '87%', Icons.star, const Color(0xFF7B1FA2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.blue[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performance Insight',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your team is performing 12% above average. Great job maintaining efficiency!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }
}

// Small centered loader overlay for a chart area
class _MiniLoader extends StatelessWidget {
  const _MiniLoader();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

// Inline date button for the Daily Hours card header.
class _InlineDateButton extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;
  const _InlineDateButton({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// Legend item used in the role distribution legend.
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String valueText;
  const _LegendItem({
    required this.color,
    required this.label,
    required this.valueText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF2D3748)),
        ),
        const SizedBox(width: 4),
        Text(
          '($valueText)',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

// Language selector reused in top bar.
class _SidebarLanguageChip extends StatefulWidget {
  @override
  State<_SidebarLanguageChip> createState() => _SidebarLanguageChipState();
}

class _SidebarLanguageChipState extends State<_SidebarLanguageChip> {
  String value = 'English';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromRGBO(255, 255, 255, 0.24),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: const Color(0xFF0F2231),
          value: value,
          items: const [
            DropdownMenuItem(
                value: 'English',
                child: Text('English', style: TextStyle(color: Colors.white))),
            DropdownMenuItem(
                value: 'Hindi',
                child: Text('Hindi', style: TextStyle(color: Colors.white))),
            DropdownMenuItem(
                value: 'Marathi',
                child: Text('Marathi', style: TextStyle(color: Colors.white))),
          ],
          onChanged: (v) => setState(() => value = v!),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}

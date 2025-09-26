// lib/Dashboard page.dart — Enhanced with comprehensive analytics dashboard (fixed)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
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
    final selectedIndex = _indexForLocation(currentPath, menu);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 12,
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F2231), Color(0xFF0B1A27)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Logo badge
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      'assets/app_logo.png', // matches pubspec
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: NavigationRailTheme(
                      data: NavigationRailThemeData(
                        backgroundColor: Colors.transparent,
                        selectedIconTheme:
                            const IconThemeData(color: Colors.white),
                        unselectedIconTheme: IconThemeData(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        selectedLabelTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelTextStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                        indicatorColor: Colors.white.withValues(alpha: 0.10),
                      ),
                      child: NavigationRail(
                        extended: true,
                        groupAlignment: -0.8,
                        minExtendedWidth: 220,
                        backgroundColor: Colors.transparent,
                        destinations: [
                          for (final m in menu)
                            NavigationRailDestination(
                              icon: Icon(m.icon),
                              selectedIcon: Icon(m.icon),
                              label: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Text(m.label),
                              ),
                            ),
                        ],
                        selectedIndex: selectedIndex,
                        onDestinationSelected: (i) => context.go(menu[i].path),
                      ),
                    ),
                  ),
                  // Replace the old Row footer (Padding with Row) with this Column footer
                  const Divider(color: Color.fromRGBO(255, 255, 255, 0.24), height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Language selector full-width
                        _SidebarLanguageChip(),
                        const SizedBox(height: 10),

                        // Profile button full-width and upright
                        
                        const SizedBox(height: 10),

                        // Logout button full-width and upright
                        SizedBox(
                          height: 40,
                          child: FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.10),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              AppState.of(context).signOut();
                              context.go('/');
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout, size: 18),
                                SizedBox(width: 8),
                                Text('Logout'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  int _indexForLocation(
      String location, List<({String label, IconData icon, String path})> menu) {
    for (int i = 0; i < menu.length; i++) {
      if (location.startsWith(menu[i].path)) return i;
    }
    return 0;
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime selectedDate = DateTime.now();

  // Sample data for demonstrations
  final Map<String, double> dailyHours = {
    'Alice': 8.5,
    'Bob': 7.0,
    'Charlie': 9.5,
    'Diana': 6.0,
    'Ethan': 8.0,
  };

  final Map<String, int> roleDistribution = {
    'Cashier': 10,
    'Cleaner': 5,
    'Chef': 7,
    'Server': 8,
    'Manager': 3,
  };

  final Map<String, double> weeklyDeviations = {
    'Monday': 2.0,
    'Tuesday': -1.0,
    'Wednesday': 0.0,
    'Thursday': 3.0,
    'Friday': -2.0,
    'Saturday': 1.0,
  };

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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workforce Analytics Dashboard',
                      style: text.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Real-time insights into your workforce performance',
                      style: text.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
                // Date Picker
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Top Row: Daily Hours Chart + Role Distribution
            Row(
              children: [
                // Daily Hours Bar Chart
                Expanded(
                  flex: 2,
                  child: _buildChartCard(
                    'Daily Work Hours by Employee',
                    'Hours worked on ${selectedDate.day}/${selectedDate.month}',
                    _buildDailyHoursChart(),
                    height: 300,
                  ),
                ),
                const SizedBox(width: 20),
                // Role Distribution Pie Chart
                Expanded(
                  flex: 1,
                  child: _buildChartCard(
                    'Staff Distribution by Role',
                    'Total employees per role this week',
                    _buildRoleDistributionChart(),
                    height: 300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Weekly Deviation Chart
            _buildChartCard(
              'Weekly Hours Deviation Analysis',
              'Daily deviation from target hours (Target: 10 hours)',
              _buildWeeklyDeviationChart(),
              height: 250,
            ),
            const SizedBox(height: 30),

            // Bottom Section: Alerts & Summary
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Alerts Section
                Expanded(
                  child: _buildAlertSection(),
                ),
                const SizedBox(width: 20),
                // Summary Section
                Expanded(
                  child: _buildSummarySection(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, String subtitle, Widget chart,
      {double? height}) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildDailyHoursChart() {
    final entries = dailyHours.entries.toList(); // for asMap()
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 12,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF3B82F6),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final employee = entries[group.x.toInt()].key;
              return BarTooltipItem(
                '$employee\n',
                const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                    text: '${rod.toY.toStringAsFixed(1)} hours',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 16),
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
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
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
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

  Widget _buildRoleDistributionChart() {
    final colors = [
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFFFF9800),
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
    ];
    final entries = roleDistribution.entries.toList(); // for asMap()
    final total = roleDistribution.values.fold<int>(0, (a, b) => a + b);

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (event, response) {},
        ),
        borderData: FlBorderData(show: false),
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: entries
            .asMap()
            .entries
            .map((e) {
              final index = e.key;
              final role = e.value.key;
              final count = e.value.value;
              final percentage = (count / total) * 100;
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
                badgeWidget: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    role,
                    style: const TextStyle(
                        fontSize: 9, color: Colors.white),
                  ),
                ),
                badgePositionPercentageOffset: 1.25,
              );
            })
            .toList(),
      ),
    );
  }

  Widget _buildWeeklyDeviationChart() {
    final entries = weeklyDeviations.entries.toList(); // for asMap()
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 4,
        minY: -3,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = entries[group.x.toInt()].key;
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
                if (value.toInt() < entries.length) {
                  final day = entries[value.toInt()].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      day.substring(0, 3),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
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
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                      top: deviation >= 0
                          ? const Radius.circular(4)
                          : Radius.zero,
                      bottom: deviation < 0
                          ? const Radius.circular(4)
                          : Radius.zero,
                    ),
                  ),
                ],
              );
            })
            .toList(),
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
          _buildSummaryItem('Hours This Week', '1,245', Icons.schedule,
              const Color(0xFF2E7D32)),
          _buildSummaryItem(
              'Average Hours/Day', '8.2', Icons.trending_up, Colors.orange),
          _buildSummaryItem('Efficiency Score', '87%', Icons.star,
              const Color(0xFF7B1FA2)),
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

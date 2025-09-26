// lib/Dashboard page.dart — clickable rail using state.uri.path
// lib/Dashboard page.dart (only the shell changed styling)
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'main.dart';

class DashboardShell extends StatelessWidget {
  final Widget child;
  const DashboardShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    

    final menu = <({String label, IconData icon, String path})>[
      (label: 'Dashboard',   icon: Icons.space_dashboard, path: '/dashboard'),
      (label: 'Shop Setup',  icon: Icons.store,           path: '/staff/staff_setup'),
      (label: 'Staff Mgmt',  icon: Icons.person,          path: '/staff/staff_management'),
      (label: 'Shift Schedule', icon: Icons.event_note,   path: '/shiftschedule'),
      (label: 'Reports / Payroll', icon: Icons.bar_chart, path: '/reportpage'),
    ];

    final currentPath = GoRouterState.of(context).uri.path;
    final selectedIndex = _indexForLocation(currentPath, menu);

    // Sidebar palette (black + white + blue feel)
    

    return Scaffold(
  appBar: AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    toolbarHeight: 12, // small spacer; can be 0 if not needed
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
              // Home badge
              // Sidebar badge (PNG/JPG)
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  'assets/logo.png',      // your path
                  fit: BoxFit.contain,    // keep proportions inside the rounded tile
                ),
              ),

              const SizedBox(height: 12),

              // Navigation rail
              Expanded(
                child: NavigationRailTheme(
                  data: NavigationRailThemeData(
                    backgroundColor: Colors.transparent,
                    selectedIconTheme: const IconThemeData(color: Colors.white),
                    unselectedIconTheme: IconThemeData(
                      color: Colors.white.withOpacity(0.85),
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelTextStyle: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                    ),
                    indicatorColor: Colors.white.withOpacity(0.10),
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
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(m.label),
                          ),
                        ),
                    ],
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (i) => context.go(menu[i].path),
                  ),
                ),
              ),

              // Utilities footer: language + profile + logout
              const Divider(color: Colors.white24, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(child: _SidebarLanguageChip()),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Profile',
                      onPressed: () {},
                      icon: const Icon(Icons.person, color: Colors.white),
                    ),
                    IconButton(
                      tooltip: 'Logout',
                      onPressed: () {
                        AppState.of(context).signOut();
                        context.go('/');
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),

      const SizedBox(width: 12),
      // Main area: just the routed child now (no top header)
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


class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Welcome to Workforce Planner',
            style: text.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Set up the shop, add staff, and generate AI schedules in minutes.',
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: const Color(0xFF0F2231),
          value: value,
          items: const [
            DropdownMenuItem(value: 'English', child: Text('English', style: TextStyle(color: Colors.white))),
            DropdownMenuItem(value: 'Hindi', child: Text('Hindi', style: TextStyle(color: Colors.white))),
            DropdownMenuItem(value: 'Marathi', child: Text('Marathi', style: TextStyle(color: Colors.white))),
          ],
          onChanged: (v) => setState(() => value = v!),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}



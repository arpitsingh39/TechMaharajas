// lib/main.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'authentication/loginpage.dart';
import 'authentication/signinpage.dart';

import 'dashboardpage.dart';              // contains DashboardShell, DashboardPage
import 'shiftschedule.dart';
import 'reportpage.dart';
import 'staff/staff_management.dart';
import 'staff/staff_setup.dart';
import 'chatbot.dart';                    // <-- add this

void main() => runApp(const WorkforceApp());

class AppAuth extends ChangeNotifier {
  bool _signedIn = false;
  bool get signedIn => _signedIn;
  void signIn() { _signedIn = true; notifyListeners(); }
  void signOut() { _signedIn = false; notifyListeners(); }
}

class AppState extends InheritedNotifier<AppAuth> {
  const AppState({super.key, required super.notifier, required super.child});
  static AppAuth of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppState>()!.notifier!;
}

class WorkforceApp extends StatefulWidget {
  const WorkforceApp({super.key});
  @override
  State<WorkforceApp> createState() => _WorkforceAppState();
}

class _WorkforceAppState extends State<WorkforceApp> {
  final auth = AppAuth();

  late final GoRouter _router = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: '/dashboard',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/signin', builder: (_, __) => const SignInPage()),

      // Keep app pages inside the shell so they share the top bar
      ShellRoute(
        builder: (context, state, child) => DashboardShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/staff/staff_setup', builder: (_, __) => const StaffSetupPage()),
          GoRoute(path: '/staff/staff_management', builder: (_, __) => const StaffManagementPage()),
          GoRoute(path: '/shiftschedule', builder: (_, __) => const ShiftSchedulePage()),
          GoRoute(path: '/reportpage', builder: (_, __) => const ReportPage()),
          // NEW chatbot route
          GoRoute(path: '/chatbot', builder: (_, __) => const ChatbotPage()),
        ],
      ),
    ],
    redirect: (ctx, state) {
      final signedIn = auth.signedIn;
      final loggingIn =
          state.matchedLocation == '/' || state.matchedLocation == '/signin';
      if (!signedIn && !loggingIn) return '/';
      if (signedIn && loggingIn) return '/dashboard';
      return null;
    },
  );

  @override
  Widget build(BuildContext context) {
    final color = Colors.blue;
    final light = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: color, brightness: Brightness.light),
      scaffoldBackgroundColor: Colors.white,
    );
    final dark = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: color, brightness: Brightness.dark),
    );

    return AppState(
      notifier: auth,
      child: MaterialApp.router(
        title: 'Workforce Planner',
        theme: light,
        darkTheme: dark,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

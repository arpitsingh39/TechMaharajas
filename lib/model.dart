/*import 'package:intl/intl.dart';

class EmployeePay {
  final String id;
  final String name;
  final String role;
  final double hours;
  final double hourlyRate;
  final double overtimeHours;
  final double bonus;

  const EmployeePay({
    required this.id,
    required this.name,
    required this.role,
    required this.hours,
    required this.hourlyRate,
    required this.overtimeHours,
    required this.bonus,
  });

  double get regularHours => (hours - overtimeHours).clamp(0, hours);
  double get regularPay => regularHours * hourlyRate;
  double get overtimePay => overtimeHours * hourlyRate * 1.5;
  double get totalPay => regularPay + overtimePay + bonus;
}

class DayLaborPoint {
  final DateTime day;
  final double hours;
  final double cost;
  final double overtimeHours;
  const DayLaborPoint(this.day, this.hours, this.cost, this.overtimeHours);
}

class PayrollSummary {
  final List<EmployeePay> employees;
  final List<DayLaborPoint> daily;
  final Map<String, double> budgetByWeek; // yyyy-ww -> budget

  const PayrollSummary({
    required this.employees,
    required this.daily,
    required this.budgetByWeek,
  });

  double get totalHours =>
      employees.fold(0.0, (s, e) => s + e.hours);
  double get totalCost =>
      employees.fold(0.0, (s, e) => s + e.totalPay);
  double get overtimeHours =>
      employees.fold(0.0, (s, e) => s + e.overtimeHours);
  double get overtimeCost =>
      employees.fold(0.0, (s, e) => s + e.overtimePay);
  double get avgHourlyRate {
    final regHours = employees.fold(0.0, (s, e) => s + e.regularHours);
    return regHours == 0 ? 0 : employees.fold(0.0, (s, e) => s + e.regularPay) / regHours;
  }

  Map<String, double> costByRole() {
    final map = <String, double>{};
    for (final e in employees) {
      map.update(e.role, (v) => v + e.totalPay, ifAbsent: () => e.totalPay);
    }
    return map;
  }

  Map<String, double> hoursByRole() {
    final map = <String, double>{};
    for (final e in employees) {
      map.update(e.role, (v) => v + e.hours, ifAbsent: () => e.hours);
    }
    return map;
  }

  Map<String, (double reg, double ot, double bonus)> payBuckets() {
    double reg = 0, ot = 0, bonus = 0;
    for (final e in employees) {
      reg += e.regularPay;
      ot  += e.overtimePay;
      bonus += e.bonus;
    }
    return {'all': (reg, ot, bonus)};
  }

  Map<String, double> overtimeByWeek() {
    final map = <String, double>{};
    for (final p in daily) {
      final w = _weekKey(p.day);
      map.update(w, (v) => v + p.overtimeHours, ifAbsent: () => p.overtimeHours);
    }
    return map;
  }

  Map<String, double> costByWeek() {
    final map = <String, double>{};
    for (final p in daily) {
      final w = _weekKey(p.day);
      map.update(w, (v) => v + p.cost, ifAbsent: () => p.cost);
    }
    return map;
  }

  static String _weekKey(DateTime d) {
    final week = int.parse(DateFormat("w").format(d));
    return "${d.year}-${week.toString().padLeft(2,'0')}";
  }
}
*/
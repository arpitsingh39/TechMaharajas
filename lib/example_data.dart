/*import 'model.dart';

PayrollSummary demoPayroll() {
  final employees = <EmployeePay>[
    EmployeePay(id: '1', name: 'Alex Smith', role: 'Cashier', hours: 38, hourlyRate: 12, overtimeHours: 2, bonus: 10),
    EmployeePay(id: '2', name: 'Maria Johnson', role: 'Sales', hours: 30, hourlyRate: 13, overtimeHours: 0, bonus: 25),
    EmployeePay(id: '3', name: 'John Doe', role: 'Stock', hours: 28, hourlyRate: 11, overtimeHours: 0, bonus: 0),
    EmployeePay(id: '4', name: 'Neha', role: 'Cashier', hours: 24, hourlyRate: 12, overtimeHours: 0, bonus: 0),
    EmployeePay(id: '5', name: 'Ravi', role: 'Sales', hours: 34, hourlyRate: 13, overtimeHours: 4, bonus: 0),
  ];

  final start = DateTime.now().subtract(const Duration(days: 27));
  final daily = List.generate(28, (i) {
    final day = start.add(Duration(days: i));
    final hours = 20 + (i % 5) * 3 + (i % 7 == 0 ? 8 : 0);
    final ot = (i % 6 == 0) ? 2.0 : 0.0;
    final cost = hours * 12.5 + ot * 12.5 * 0.5;
    return DayLaborPoint(day, hours.toDouble(), cost, ot);
  });

  final budget = {
    for (final p in daily)
      PayrollSummary._weekKey(p.day): 750.0,
  };

  return PayrollSummary(employees: employees, daily: daily, budgetByWeek: budget);
}
*/
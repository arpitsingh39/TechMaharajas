// lib/Report page.dart
import 'package:flutter/material.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});
  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Alex Smith', 'Cashier', 40, 12.5),
      ('Maria Johnson', 'Sales', 32, 13.0),
    ];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Payroll Summary', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          child: DataTable(columns: const [
            DataColumn(label: Text('Employee')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('Hours')),
            DataColumn(label: Text('Rate')),
            DataColumn(label: Text('Pay')),
          ], rows: [
            for (final r in rows)
              DataRow(cells: [
                DataCell(Text(r.$1)),
                DataCell(Text(r.$2)),
                DataCell(Text('${r.$3}')),
                DataCell(Text('₹${r.$4.toStringAsFixed(2)}')),
                DataCell(Text('₹${(r.$3 * r.$4).toStringAsFixed(2)}')),
              ]),
          ]),
        ),
      ]),
    );
  }
}

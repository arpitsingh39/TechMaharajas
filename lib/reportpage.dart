// lib/Report page.dart
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Excel export
import 'package:excel/excel.dart'; // pubspec: excel: ^4.0.6  [web:98]
import 'dart:typed_data';
// For Flutter Web download
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html; // Blob + AnchorElement for download  [web:135][web:145]

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  // Sample data based on your JSON structure
  final List<Map<String, dynamic>> staffData = const [
    {
      "Name": "Aisha Khan",
      "Role": "Cashier",
      "Hourly Rate (₹)": 1248.75,
      "Total Hours": 16.0,
      "Total Pay (₹)": 19980.0
    },
    {
      "Name": "Rohit Verma",
      "Role": "Cleaner",
      "Hourly Rate (₹)": 1123.88,
      "Total Hours": 16.0,
      "Total Pay (₹)": 17982.08
    },
    {
      "Name": "Meera Joshi",
      "Role": "Chef",
      "Hourly Rate (₹)": 1831.5,
      "Total Hours": 16.0,
      "Total Pay (₹)": 29304.0
    },
    {
      "Name": "Arjun Singh",
      "Role": "Server",
      "Hourly Rate (₹)": 1207.12,
      "Total Hours": 16.0,
      "Total Pay (₹)": 19313.92
    },
    {
      "Name": "Sara Thomas",
      "Role": "Manager",
      "Hourly Rate (₹)": 2331.0,
      "Total Hours": 8.0,
      "Total Pay (₹)": 18648.0
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reports & Payroll',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Weekly Staff Summary',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.blue[600]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Payroll',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${staffData.fold<double>(0, (sum, staff) => sum + staff["Total Pay (₹)"]).toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Staff Cards List
            Expanded(
              child: ListView.builder(
                itemCount: staffData.length,
                itemBuilder: (context, index) {
                  final staff = staffData[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      elevation: 2,
                      shadowColor: Colors.grey.withOpacity(0.3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _navigateToStaffDetail(context, staff),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  // Avatar
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: _getRoleColor(staff["Role"]).withOpacity(0.2),
                                    child: Text(
                                      staff["Name"].toString().split(' ').map((e) => e[0]).join('').toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _getRoleColor(staff["Role"]),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          staff["Name"],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(staff["Role"]).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            staff["Role"],
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: _getRoleColor(staff["Role"]),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Pay
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${staff["Total Pay (₹)"].toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      Text(
                                        '${staff["Total Hours"]} hrs',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              // Hours and Rate
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildInfoItem('Rate', '₹${staff["Hourly Rate (₹)"].toStringAsFixed(2)}/hr'),
                                    Container(height: 20, width: 1, color: Colors.grey[300]),
                                    _buildInfoItem('Hours', '${staff["Total Hours"]}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Page-level export buttons
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _exportPayrollPdf(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export as PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _exportPayrollExcel(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.grid_on),
                    label: const Text('Export as Excel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
        return Colors.purple;
      case 'chef':
        return Colors.orange;
      case 'cashier':
        return Colors.blue;
      case 'server':
        return Colors.green;
      case 'cleaner':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  void _navigateToStaffDetail(BuildContext context, Map<String, dynamic> staff) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaffDetailPage(staff: staff),
      ),
    );
  }

  // Page-level PDF export
  Future<void> _exportPayrollPdf(BuildContext context) async {
    final pdf = pw.Document();

    final headers = ['Name', 'Role', 'Hourly Rate (₹)', 'Total Hours', 'Total Pay (₹)'];
    final rows = staffData.map((s) {
      return [
        s['Name'],
        s['Role'],
        '₹${(s['Hourly Rate (₹)'] as num).toStringAsFixed(2)}',
        (s['Total Hours'] as num).toStringAsFixed(1),
        '₹${(s['Total Pay (₹)'] as num).toStringAsFixed(2)}',
      ];
    }).toList();

    final total = staffData.fold<num>(0, (sum, s) => sum + (s['Total Pay (₹)'] as num));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text('Staff Payroll Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Total Payroll: ₹${total.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(6),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // Page-level Excel export (summary)
  Future<void> _exportPayrollExcel() async {
    final excel = Excel.createExcel();
    final sheet = excel.sheets[excel.getDefaultSheet()!]!;

    const headers = ['Name', 'Role', 'Hourly Rate (₹)', 'Total Hours', 'Total Pay (₹)'];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList()); // CellValue  [web:98][web:108]

    for (final s in staffData) {
      sheet.appendRow([
        TextCellValue(s['Name'] as String),
        TextCellValue(s['Role'] as String),
        TextCellValue((s['Hourly Rate (₹)'] as num).toStringAsFixed(2)),
        TextCellValue((s['Total Hours'] as num).toStringAsFixed(1)),
        TextCellValue((s['Total Pay (₹)'] as num).toStringAsFixed(2)),
      ]); // wrap values  [web:98][web:108]
    }

    final Uint8List bytes = excel.encode() as Uint8List;

    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ); // web download  [web:135][web:145]
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = 'payroll_report.xlsx'
      ..style.display = 'none';
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }
}

class StaffDetailPage extends StatelessWidget {
  final Map<String, dynamic> staff;

  const StaffDetailPage({super.key, required this.staff});

  // Mock daily schedule data
  List<Map<String, dynamic>> getDailySchedule() {
    return [
      {'day': 'Monday', 'hours': 4.0, 'shift': '9:00 AM - 1:00 PM'},
      {'day': 'Tuesday', 'hours': 0.0, 'shift': 'Off'},
      {'day': 'Wednesday', 'hours': 6.0, 'shift': '2:00 PM - 8:00 PM'},
      {'day': 'Thursday', 'hours': 3.0, 'shift': '6:00 PM - 9:00 PM'},
      {'day': 'Friday', 'hours': 3.0, 'shift': '10:00 AM - 1:00 PM'},
      {'day': 'Saturday', 'hours': 0.0, 'shift': 'Off'},
      {'day': 'Sunday', 'hours': 0.0, 'shift': 'Off'},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dailySchedule = getDailySchedule();
    final hourlyRate = staff["Hourly Rate (₹)"];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(staff["Name"]),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          // Export Excel for this staff detail page
          IconButton(
            tooltip: 'Export Excel',
            icon: const Icon(Icons.grid_on),
            onPressed: () => _exportStaffExcel(staff, dailySchedule, hourlyRate),
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generatePDF(context, dailySchedule, hourlyRate),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Staff Info Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo[400]!, Colors.indigo[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: Text(
                      staff["Name"].toString().split(' ').map((e) => e[0]).join('').toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff["Name"],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          staff["Role"],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹${staff["Total Pay (₹)"].toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Daily Schedule Table
            Text(
              'Daily Schedule & Pay',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 20,
                    headingRowHeight: 60,
                    dataRowHeight: 56,
                    columns: const [
                      DataColumn(label: Text('Day', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Hours', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Daily Pay', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: dailySchedule.map((day) {
                      final dailyPay = day['hours'] * hourlyRate;
                      return DataRow(
                        cells: [
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  day['day'],
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                ),
                                Text(
                                  day['shift'],
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              day['hours'] == 0 ? '-' : '${day['hours']}h',
                              style: TextStyle(
                                color: day['hours'] == 0 ? Colors.grey : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${hourlyRate.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                            ),
                          ),
                          DataCell(
                            Text(
                              dailyPay == 0 ? '-' : '₹${dailyPay.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: dailyPay == 0 ? Colors.grey : Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            // PDF Export Button (per-staff detail)
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _generatePDF(context, dailySchedule, hourlyRate),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[400],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Export as PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // Per-staff Excel export (detail page)
  Future<void> _exportStaffExcel(
    Map<String, dynamic> staff,
    List<Map<String, dynamic>> dailySchedule,
    double hourlyRate,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel.sheets[excel.getDefaultSheet()!]!;

    // Staff header info
    sheet.appendRow([TextCellValue('Staff Payroll Report')]); // title  [web:98][web:108]
    sheet.appendRow([TextCellValue('Name:'), TextCellValue(staff['Name'] as String)]);
    sheet.appendRow([TextCellValue('Role:'), TextCellValue(staff['Role'] as String)]);
    sheet.appendRow([TextCellValue('Hourly Rate (₹):'), TextCellValue(hourlyRate.toStringAsFixed(2))]);
    sheet.appendRow([TextCellValue('Total Pay (₹):'), TextCellValue((staff['Total Pay (₹)'] as num).toStringAsFixed(2))]);

    sheet.appendRow([TextCellValue('')]); // blank line

    // Daily schedule table header
    sheet.appendRow([
      TextCellValue('Day'),
      TextCellValue('Hours'),
      TextCellValue('Rate (₹)'),
      TextCellValue('Daily Pay (₹)'),
      TextCellValue('Shift'),
    ]);

    // Daily rows
    for (final d in dailySchedule) {
      final hours = d['hours'] as num;
      final dailyPay = hours * hourlyRate;
      sheet.appendRow([
        TextCellValue(d['day'] as String),
        TextCellValue(hours == 0 ? '-' : hours.toStringAsFixed(1)),
        TextCellValue(hourlyRate.toStringAsFixed(2)),
        TextCellValue(dailyPay == 0 ? '-' : dailyPay.toStringAsFixed(2)),
        TextCellValue(d['shift'] as String),
      ]);
    }

    final Uint8List bytes = excel.encode() as Uint8List;

    final blob = html.Blob(
      [bytes],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ); // download  [web:135][web:145]
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = '${staff['Name']}_payroll.xlsx'
      ..style.display = 'none';
    html.document.body!.children.add(anchor);
    anchor.click();
    html.document.body!.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _generatePDF(
      BuildContext context, List<Map<String, dynamic>> dailySchedule, double hourlyRate) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text('Staff Payroll Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Name: ${staff["Name"]}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Role: ${staff["Role"]}', style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 4),
                  pw.Text('Hourly Rate: ₹${hourlyRate.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 4),
                  pw.Text('Total Pay: ₹${staff["Total Pay (₹)"].toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Daily Schedule', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Day', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Hours', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Rate', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Daily Pay', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Shift', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ],
                ),
                ...dailySchedule.map((d) {
                  final hours = d['hours'] as num;
                  final dailyPay = hours * hourlyRate;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(d['day'] as String)),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(hours == 0 ? '-' : '${hours.toStringAsFixed(1)}h')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('₹${hourlyRate.toStringAsFixed(2)}')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(dailyPay == 0 ? '-' : '₹${dailyPay.toStringAsFixed(2)}')),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(d['shift'] as String)),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}

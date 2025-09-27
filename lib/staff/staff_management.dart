// lib/staff/staff management.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class StaffMember {
  String name;
  String role;
  String contact;
  // Availability kept in model for backward compatibility, but not shown/edited in UI.
  String availability;
  int maxHours; // max hours per week
  double hourlyRate; // hourly rate

  StaffMember({
    required this.name,
    required this.role,
    required this.contact,
    required this.availability,
    this.maxHours = 40,
    this.hourlyRate = 1200.0,
  });
}

class StaffManagementPage extends StatefulWidget {
  const StaffManagementPage({super.key});
  @override
  State<StaffManagementPage> createState() => _StaffManagementPageState();
}

class _StaffManagementPageState extends State<StaffManagementPage> {
  // API config
  static const String _base = 'https://studious-space-cod-7qjp49qj756fg74-5000.app.github.dev';
  static const String _staffViewPath = '/api/staff/view';
  static const String _staffCreatePath = '/api/staff/create';

  // TODO: Replace this with real shop selection / app state.
  static const int _shopId = 1;

  // UI state
  bool _loading = false;
  String? _error;

  final roles = <String>[
    'Cashier',
    'Cleaner',
    'Chef',
    'Server',
    'Manager',
    'Sales',
    'Stock',
    'Barista'
  ];

  final List<StaffMember> staff = [
    // Initial placeholders; replaced by API on load.
    StaffMember(
      name: 'Aisha Khan',
      role: 'Cashier',
      contact: '+91 98765 43210',
      availability: 'Mon 09:00–17:00; Wed 09:00–17:00; Fri 09:00–17:00',
      maxHours: 40,
      hourlyRate: 1248.75,
    ),
    StaffMember(
      name: 'Rohit Verma',
      role: 'Cleaner',
      contact: '+91 87654 32109',
      availability: 'Tue 10:00–18:00; Thu 10:00–18:00; Sat 08:00–16:00',
      maxHours: 35,
      hourlyRate: 1123.88,
    ),
    StaffMember(
      name: 'Meera Joshi',
      role: 'Chef',
      contact: '+91 76543 21098',
      availability: 'Mon 08:00–16:00; Tue 08:00–16:00; Wed 08:00–16:00',
      maxHours: 45,
      hourlyRate: 1831.5,
    ),
    StaffMember(
      name: 'Arjun Singh',
      role: 'Server',
      contact: '+91 65432 10987',
      availability: 'Thu 12:00–20:00; Fri 12:00–20:00; Sat 12:00–20:00',
      maxHours: 35,
      hourlyRate: 1207.12,
    ),
    StaffMember(
      name: 'Sara Thomas',
      role: 'Manager',
      contact: '+91 54321 09876',
      availability: 'Mon 09:00–17:00; Tue 09:00–17:00; Wed 09:00–17:00',
      maxHours: 50,
      hourlyRate: 2331.0,
    ),
  ];

  int? _sortColumnIndex;
  bool _sortAscending = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_base$_staffViewPath').replace(queryParameters: {
        'shop_id': _shopId.toString(),
      });

      final res = await http.get(uri, headers: {'Accept': 'application/json'});

      if (res.statusCode < 200 || res.statusCode >= 300) {
        // ignore: avoid_print
        print('GET $_staffViewPath failed: ${res.statusCode} ${res.reasonPhrase}');
        // ignore: avoid_print
        print('Body: ${res.body}');
        throw Exception('HTTP ${res.statusCode}');
      }

      final decoded = _safeDecode(res.body);
      final list = _extractList(decoded);
      final loaded = _mapStaffList(list);

      setState(() {
        staff
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load staff. Showing local data.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<StaffMember?> _createStaff(StaffMember s) async {
  final uri = Uri.parse('$_base$_staffCreatePath');

  // Map to backend-required keys and types
  final payload = {
    'shop_id': _shopId,                         // int
    'full_name': s.name.trim(),                 // string
    'role_name': s.role.trim(),                 // string
    'contact': s.contact.trim(),                // keep if backend accepts it
    'availability': s.availability,             // optional
    'max_hours_per_week': s.maxHours,           // int
    'hourly_rate': s.hourlyRate,                // number (if accepted)
  };

  final res = await http.post(
    uri,
    headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    body: jsonEncode(payload),
  );

  if (res.statusCode < 200 || res.statusCode >= 300) {
    // ignore: avoid_print
    print('POST $_staffCreatePath failed: ${res.statusCode} ${res.reasonPhrase}');
    // ignore: avoid_print
    print('Body: ${res.body}');
    return null;
  }

  // Prefer server-returned row
  final decoded = _safeDecode(res.body);
  final list = _extractList(decoded);
  final mapped = _mapStaffList(list);
  if (mapped.isNotEmpty) return mapped.first;

  // If server doesn’t echo the new row, fall back to local object
  return s;
}


  dynamic _safeDecode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      final i = s.indexOf('{');
      if (i >= 0) {
        try {
          return jsonDecode(s.substring(i));
        } catch (_) {}
      }
      return [];
    }
  }

  dynamic _extractList(dynamic json) {
    if (json is List) return json;
    if (json is Map) {
      for (final k in [
        'data',
        'result',
        'items',
        'staff',
        'records',
        'results',
        'staff_list'
      ]) {
        final v = json[k];
        if (v is List) return v;
        if (v is Map) {
          for (final kk in ['items', 'list', 'records', 'results']) {
            final vv = v[kk];
            if (vv is List) return vv;
          }
        }
      }
      if (json.containsKey('name') || json.containsKey('fullName')) {
        return [json];
      }
    }
    return [];
  }

  List<StaffMember> _mapStaffList(dynamic listJson) {
    final list = (listJson is List) ? listJson : <dynamic>[];
    final out = <StaffMember>[];
    for (final e in list) {
      if (e is! Map) continue;

      final name = (e['name'] ?? e['fullName'] ?? e['employeeName'] ?? '').toString().trim();
      final role = (e['role'] ?? e['position'] ?? '').toString().trim();
      final contact = (e['contact'] ?? e['phone'] ?? e['phoneNumber'] ?? '').toString().trim();

      final availability = (e['availability'] ?? e['avail'] ?? '—').toString();
      final maxHours = (e['maxHours'] is num)
          ? (e['maxHours'] as num).toInt()
          : int.tryParse('${e['max_hours'] ?? e['max_per_week'] ?? ''}') ?? 40;
      final hourlyRate = (e['hourlyRate'] is num)
          ? (e['hourlyRate'] as num).toDouble()
          : double.tryParse('${e['hourly_rate'] ?? e['rate'] ?? ''}') ?? 0.0;

      if (name.isEmpty) continue;

      out.add(StaffMember(
        name: name,
        role: role.isEmpty ? 'Staff' : role,
        contact: contact,
        availability: availability,
        maxHours: maxHours,
        hourlyRate: hourlyRate,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final filteredStaff = staff
        .where((s) =>
            s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            s.role.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Staff Management',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[600]!, Colors.blue[700]!],
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
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final draft = await showDialog<StaffMember>(
                              context: context,
                              builder: (_) => _StaffEditorDialog(roles: roles),
                            );
                            if (draft != null) {
                              final saved = await _createStaff(draft);
                              if (saved != null) {
                                setState(() => staff.add(saved));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Staff created successfully')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to save staff on server')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.person_add, size: 20),
                          label: const Text(
                            'Add Staff',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Search Bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
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
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search staff by name or role...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey[400]),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),

            // Staff Table
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.people, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Staff Members (${filteredStaff.length})',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const Spacer(),
                          if (_loading)
                            const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),

                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            border: Border.all(color: Colors.amber[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                                color: Colors.amber[900], fontSize: 12),
                          ),
                        ),
                      ),

                    // Table Content
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchStaff,
                        child: Builder(builder: (context) {
                          final filtered = staff
                              .where((s) =>
                                  s.name
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase()) ||
                                  s.role
                                      .toLowerCase()
                                      .contains(_searchQuery.toLowerCase()))
                              .toList();

                          if (filtered.isEmpty) {
                            return ListView(
                              children: [
                                SizedBox(height: 300, child: _buildEmptyState())
                              ],
                            );
                          }

                          return SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: DataTable(
                              columnSpacing: 20,
                              headingRowHeight: 60,
                              dataRowHeight: 70,
                              sortColumnIndex: _sortColumnIndex,
                              sortAscending: _sortAscending,
                              headingTextStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[700],
                                fontSize: 14,
                              ),
                              columns: [
                                DataColumn(
                                  label: const Text('Employee Name'),
                                  onSort: (i, asc) =>
                                      _sortBy((s) => s.name, i, asc),
                                ),
                                DataColumn(
                                  label: const Text('Role'),
                                  onSort: (i, asc) =>
                                      _sortBy((s) => s.role, i, asc),
                                ),
                                const DataColumn(label: Text('Contact')),
                                const DataColumn(label: Text('Max Hours')),
                                const DataColumn(label: Text('Hourly Rate')),
                                const DataColumn(label: Text('Actions')),
                              ],
                              rows: filtered.map((s) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: _getRoleColor(s.role)
                                                .withOpacity(0.2),
                                            child: Text(
                                              s.name
                                                  .split(' ')
                                                  .map((e) => e[0])
                                                  .join('')
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: _getRoleColor(s.role),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                s.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(s.role)
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: _getRoleColor(s.role)
                                                .withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          s.role,
                                          style: TextStyle(
                                            color: _getRoleColor(s.role),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          Icon(Icons.phone,
                                              size: 14, color: Colors.grey[500]),
                                          const SizedBox(width: 4),
                                          Text(
                                            s.contact,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${s.maxHours}h/week',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '₹${s.hourlyRate.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.blue
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: IconButton(
                                              tooltip: 'Edit',
                                              icon: Icon(Icons.edit,
                                                  size: 18,
                                                  color: Colors.blue[600]),
                                              onPressed: () async {
                                                final updated = await showDialog<
                                                    StaffMember>(
                                                  context: context,
                                                  builder: (_) =>
                                                      _StaffEditorDialog(
                                                          roles: roles,
                                                          existing: s),
                                                );
                                                if (updated != null) {
                                                  setState(() {
                                                    s.name = updated.name;
                                                    s.role = updated.role;
                                                    s.contact = updated.contact;
                                                    s.maxHours =
                                                        updated.maxHours;
                                                    s.hourlyRate =
                                                        updated.hourlyRate;
                                                  });
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.red
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: IconButton(
                                              tooltip: 'Delete',
                                              icon: Icon(Icons.delete,
                                                  size: 18,
                                                  color: Colors.red[600]),
                                              onPressed: () =>
                                                  _showDeleteDialog(s),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No staff members yet' : 'No staff found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Add your first team member to get started'
                : 'Try a different search term',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(StaffMember s) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.warning, color: Colors.red[600], size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Remove Staff Member'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to remove ${s.name} from your team?'),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() => staff.remove(s));
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
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
      case 'sales':
        return Colors.indigo;
      case 'stock':
        return Colors.brown;
      case 'barista':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  void _sortBy(
      Comparable Function(StaffMember) key, int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      staff.sort((a, b) {
        final kA = key(a), kB = key(b);
        final result = Comparable.compare(kA, kB);
        return ascending ? result : -result;
      });
    });
  }
}

class _StaffEditorDialog extends StatefulWidget {
  final List<String> roles;
  final StaffMember? existing;
  const _StaffEditorDialog({required this.roles, this.existing});

  @override
  State<_StaffEditorDialog> createState() => _StaffEditorDialogState();
}

class _StaffEditorDialogState extends State<_StaffEditorDialog> {
  final name = TextEditingController();
  final contact = TextEditingController();
  final maxHoursController = TextEditingController();
  // Removed hourlyRateController from UI, but keep model field
  String role = '';

  @override
  void initState() {
    super.initState();
    role = widget.roles.first;
    maxHoursController.text = '40';

    if (widget.existing != null) {
      name.text = widget.existing!.name;
      contact.text = widget.existing!.contact;
      role = widget.existing!.role;
      maxHoursController.text = widget.existing!.maxHours.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.existing == null ? Icons.person_add : Icons.edit,
                      color: Colors.blue[600],
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.existing == null
                        ? 'Add New Staff Member'
                        : 'Edit Staff Member',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Basic Information
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: const Icon(Icons.work),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: role,
                          isExpanded: true,
                          items: widget.roles
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: _getRoleColor(r),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(r),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => role = v!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: contact,
                      decoration: InputDecoration(
                        labelText: 'Contact Number',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Work Information (Hourly Rate field removed)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Work Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: maxHoursController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Max Hours/Week',
                              prefixIcon: const Icon(Icons.schedule),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ),
                        // Hourly rate input intentionally removed
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final result = StaffMember(
                        name: name.text.trim(),
                        role: role,
                        contact: contact.text.trim(),
                        // Availability removed from UI: keep previous value on edit, or set placeholder for new
                        availability: widget.existing?.availability ?? '—',
                        maxHours: int.tryParse(maxHoursController.text) ?? 40,
                        // Hourly rate removed from UI: preserve on edit; default to 0 for new
                        hourlyRate: widget.existing?.hourlyRate ?? 0.0,
                      );
                      Navigator.pop(context, result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.existing == null ? 'Add Staff' : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      case 'sales':
        return Colors.indigo;
      case 'stock':
        return Colors.brown;
      case 'barista':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

// lib/staff/staff set up.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RoleData {
  String roleName;
  double hourlyRate;
  String currency;
  int totalWorkers;
  String description;

  RoleData({
    required this.roleName,
    required this.hourlyRate,
    required this.currency,
    required this.totalWorkers,
    required this.description,
  });
}

class StaffSetupPage extends StatefulWidget {
  const StaffSetupPage({super.key});
  @override
  State<StaffSetupPage> createState() => _StaffSetupPageState();
}

class _StaffSetupPageState extends State<StaffSetupPage> {
  // API base and paths
  static const String _base = 'https://studious-space-cod-7qjp49qj756fg74-5000.app.github.dev';
  static const String _roleInfoPath = '/api/roleinfo';
  static const String _addRolePath = '/api/addrole';

  // If backend requires shop scoping
  static const int _shopId = 1;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool _loading = false;
  String? _error;

  final List<RoleData> roles = [
    RoleData(
      roleName: 'Cashier',
      hourlyRate: 1248.75,
      currency: '₹',
      totalWorkers: 6,
      description: 'Handles customer payments, processes orders, and manages the cash register.',
    ),
    RoleData(
      roleName: 'Cleaner',
      hourlyRate: 1123.88,
      currency: '₹',
      totalWorkers: 4,
      description: 'Maintains cleanliness of the restaurant premises including dining area and kitchen.',
    ),
    RoleData(
      roleName: 'Chef',
      hourlyRate: 1831.50,
      currency: '₹',
      totalWorkers: 5,
      description: 'Prepares meals, manages kitchen staff, and ensures food quality and safety standards.',
    ),
    RoleData(
      roleName: 'Server',
      hourlyRate: 1207.12,
      currency: '₹',
      totalWorkers: 8,
      description: 'Takes orders, serves food and beverages, and attends to customers\' needs.',
    ),
    RoleData(
      roleName: 'Manager',
      hourlyRate: 2331.00,
      currency: '₹',
      totalWorkers: 2,
      description: 'Oversees operations, manages staff, handles customer issues, and ensures smooth workflow.',
    ),
  ];

  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchRoles();
  }

  Future<void> _fetchRoles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_base$_roleInfoPath').replace(queryParameters: {
        'shop_id': _shopId.toString(),
      });

      final res = await http.get(uri, headers: {'Accept': 'application/json'});

      if (res.statusCode < 200 || res.statusCode >= 300) {
        // ignore: avoid_print
        print('GET $_roleInfoPath failed: ${res.statusCode} ${res.reasonPhrase}');
        // ignore: avoid_print
        print('Body: ${res.body}');
        throw Exception('HTTP ${res.statusCode}');
      }

      final decoded = _safeDecode(res.body);
      final list = _extractList(decoded);
      final loaded = _mapRoles(list);

      setState(() {
        roles
          ..clear()
          ..addAll(loaded);
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load roles. Showing local data.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<RoleData?> _createRole(RoleData r) async {
    final uri = Uri.parse('$_base$_addRolePath');

    // Align to backend expectations: rname, hrate (number), workers, desc, shop_id
    final payload = {
  'shop_id': _shopId,                   // if required
  'role_name': r.roleName.trim(),       // server requires this exact key
  'hrate': r.hourlyRate,                // keep as number; change to 'hourly_rate' if server asks later
  'workers': r.totalWorkers,            // change to 'total_workers' if server asks later
  'desc': r.description.trim(),         // change to 'description' if server asks later
};


    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        // ignore: avoid_print
        print('POST $_addRolePath failed: ${res.statusCode} ${res.reasonPhrase}');
        // ignore: avoid_print
        print('Body: ${res.body}');
        return null;
      }

      final decoded = _safeDecode(res.body);
      final list = _extractList(decoded);
      final mapped = _mapRoles(list);
      if (mapped.isNotEmpty) return mapped.first;

      // If server doesn’t echo the role, return provisional
      return r;
    } catch (e) {
      // On Flutter Web, a CORS/preflight issue will surface here as ClientException: Failed to fetch
      // ignore: avoid_print
      print('POST $_addRolePath network error: $e');
      return null;
    }
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
      for (final k in ['data', 'result', 'items', 'roles', 'records', 'results']) {
        final v = json[k];
        if (v is List) return v;
        if (v is Map) {
          for (final kk in ['items', 'list', 'records', 'results']) {
            final vv = v[kk];
            if (vv is List) return vv;
          }
        }
      }
      if (json.containsKey('role_name') || json.containsKey('roleName') || json.containsKey('rname')) {
        return [json];
      }
    }
    return [];
  }

  List<RoleData> _mapRoles(dynamic listJson) {
    final list = (listJson is List) ? listJson : <dynamic>[];
    final out = <RoleData>[];
    for (final e in list) {
      if (e is! Map) continue;

      final roleName = (e['role_name'] ?? e['roleName'] ?? e['rname'] ?? '').toString().trim();
      if (roleName.isEmpty) continue;

      final hr = (e['hourly_rate'] is num)
          ? (e['hourly_rate'] as num).toDouble()
          : (e['hourlyRate'] is num)
              ? (e['hourlyRate'] as num).toDouble()
              : (e['hrate'] is num)
                  ? (e['hrate'] as num).toDouble()
                  : double.tryParse('${e['rate'] ?? ''}') ?? 0.0;

      final currency = (e['currency'] ?? '₹').toString();

      final workers = (e['total_workers'] is num)
          ? (e['total_workers'] as num).toInt()
          : (e['totalWorkers'] is num)
              ? (e['totalWorkers'] as num).toInt()
              : (e['workers'] is num)
                  ? (e['workers'] as num).toInt()
                  : int.tryParse('${e['workers'] ?? ''}') ?? 0;

      final desc = (e['description'] ?? e['desc'] ?? '').toString();

      out.add(RoleData(
        roleName: roleName,
        hourlyRate: hr,
        currency: currency,
        totalWorkers: workers,
        description: desc,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final filteredRoles = roles.where((role) =>
        role.roleName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        role.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

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
                            'Roles Management',
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
                          onPressed: () => _showAddRoleDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text(
                            'Add Role',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Stats Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Roles',
                          '${roles.length}',
                          Icons.work_outline,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Total Workers',
                          '${roles.fold<int>(0, (sum, role) => sum + role.totalWorkers)}',
                          Icons.people_outline,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
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
                  hintText: 'Search roles by name or description...',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ),

            // Roles Table
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
                          Icon(Icons.work, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Role Definitions (${filteredRoles.length})',
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
                            style: TextStyle(color: Colors.amber[900], fontSize: 12),
                          ),
                        ),
                      ),

                    // Table Content
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetchRoles,
                        child: filteredRoles.isEmpty
                            ? ListView(children: [SizedBox(height: 300, child: _buildEmptyState())])
                            : SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: DataTable(
                                  columnSpacing: 16,
                                  headingRowHeight: 60,
                                  dataRowHeight: 80,
                                  sortColumnIndex: _sortColumnIndex,
                                  sortAscending: _sortAscending,
                                  headingTextStyle: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                    fontSize: 14,
                                  ),
                                  columns: [
                                    DataColumn(
                                      label: const Text('Role Name'),
                                      onSort: (i, asc) => _sortBy((r) => r.roleName, i, asc),
                                    ),
                                    DataColumn(
                                      label: const Text('Hourly Rate'),
                                      onSort: (i, asc) => _sortBy((r) => r.hourlyRate, i, asc),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: const Text('Total Workers'),
                                      onSort: (i, asc) => _sortBy((r) => r.totalWorkers, i, asc),
                                      numeric: true,
                                    ),
                                    const DataColumn(label: Text('Description')),
                                    const DataColumn(label: Text('Actions')),
                                  ],
                                  rows: filteredRoles.map((role) {
                                    return DataRow(
                                      cells: [
                                        // Role Name
                                        DataCell(
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: _getRoleColor(role.roleName).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  _getRoleIcon(role.roleName),
                                                  color: _getRoleColor(role.roleName),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                role.roleName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Hourly Rate (FittedBox to prevent overflow)
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.green.withOpacity(0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '${role.currency}${role.hourlyRate.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Total Workers
                                        DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '${role.totalWorkers}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        ),

                                        // Description
                                        DataCell(
                                          SizedBox(
                                            width: 200,
                                            child: Text(
                                              role.description,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),

                                        // Actions
                                                                                DataCell(
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  tooltip: 'Edit Role',
                                                  icon: Icon(Icons.edit, size: 18, color: Colors.blue[600]),
                                                  onPressed: () => _showEditRoleDialog(role),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: IconButton(
                                                  tooltip: 'Delete Role',
                                                  icon: Icon(Icons.delete, size: 18, color: Colors.red[600]),
                                                  onPressed: () => _showDeleteDialog(role),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  title,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No roles defined yet' : 'No roles found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Define your first role to get started'
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

  void _showAddRoleDialog() {
    _showRoleDialog();
  }

  void _showEditRoleDialog(RoleData role) {
    _showRoleDialog(existingRole: role);
  }

  void _showRoleDialog({RoleData? existingRole}) {
    final nameController = TextEditingController(text: existingRole?.roleName ?? '');
    final rateController = TextEditingController(text: existingRole?.hourlyRate.toStringAsFixed(2) ?? '');
    final totalWorkersController = TextEditingController(text: existingRole?.totalWorkers.toString() ?? '');
    final descriptionController = TextEditingController(text: existingRole?.description ?? '');

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                        existingRole == null ? Icons.add_business : Icons.edit,
                        color: Colors.blue[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      existingRole == null ? 'Add New Role' : 'Edit Role',
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
                        'Role Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Role Name',
                          prefixIcon: const Icon(Icons.work),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: rateController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Hourly Rate (₹)',
                                prefixIcon: const Icon(Icons.currency_rupee),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: totalWorkersController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Total Workers',
                          prefixIcon: const Icon(Icons.people),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Role Description',
                          prefixIcon: const Icon(Icons.description),
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

                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final newRole = RoleData(
                          roleName: nameController.text.trim(),
                          hourlyRate: double.tryParse(rateController.text) ?? 0.0,
                          currency: '₹',
                          totalWorkers: int.tryParse(totalWorkersController.text) ?? 0,
                          description: descriptionController.text.trim(),
                        );

                        if (existingRole != null) {
                          setState(() {
                            final index = roles.indexOf(existingRole);
                            roles[index] = newRole;
                          });
                          Navigator.pop(context);
                          return;
                        }

                        // Create via API, then update table
                        final saved = await _createRole(newRole);
                        if (saved != null) {
                          setState(() => roles.add(saved));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Role added successfully')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to add role on server')),
                          );
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        existingRole == null ? 'Add Role' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(RoleData role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            const Text('Delete Role'),
          ],
        ),
        content: Text('Are you sure you want to delete the "${role.roleName}" role?'),
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
              setState(() => roles.remove(role));
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String roleName) {
    switch (roleName.toLowerCase()) {
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
        return Colors.indigo;
    }
  }

  IconData _getRoleIcon(String roleName) {
    switch (roleName.toLowerCase()) {
      case 'manager':
        return Icons.supervisor_account;
      case 'chef':
        return Icons.restaurant;
      case 'cashier':
        return Icons.point_of_sale;
      case 'server':
        return Icons.room_service;
      case 'cleaner':
        return Icons.cleaning_services;
      default:
        return Icons.work;
    }
  }

  void _sortBy(Comparable Function(RoleData) key, int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      roles.sort((a, b) {
        final kA = key(a), kB = key(b);
        final result = Comparable.compare(kA, kB);
        return ascending ? result : -result;
      });
    });
  }
}


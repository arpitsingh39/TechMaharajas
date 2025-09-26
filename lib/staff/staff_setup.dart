// lib/staff/staff set up.dart
import 'package:flutter/material.dart';

class RoleData {
  String roleName;
  double hourlyRate;
  String currency;
  int totalWorkers;
  int assignedCount;
  String description;

  RoleData({
    required this.roleName,
    required this.hourlyRate,
    required this.currency,
    required this.totalWorkers,
    required this.assignedCount,
    required this.description,
  });
}

class StaffSetupPage extends StatefulWidget {
  const StaffSetupPage({super.key});
  @override
  State<StaffSetupPage> createState() => _StaffSetupPageState();
}

class _StaffSetupPageState extends State<StaffSetupPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<RoleData> roles = [
    RoleData(
      roleName: 'Cashier',
      hourlyRate: 1248.75,
      currency: '₹',
      totalWorkers: 6,
      assignedCount: 3,
      description: 'Handles customer payments, processes orders, and manages the cash register.',
    ),
    RoleData(
      roleName: 'Cleaner',
      hourlyRate: 1123.88,
      currency: '₹',
      totalWorkers: 4,
      assignedCount: 3,
      description: 'Maintains cleanliness of the restaurant premises including dining area and kitchen.',
    ),
    RoleData(
      roleName: 'Chef',
      hourlyRate: 1831.50,
      currency: '₹',
      totalWorkers: 5,
      assignedCount: 3,
      description: 'Prepares meals, manages kitchen staff, and ensures food quality and safety standards.',
    ),
    RoleData(
      roleName: 'Server',
      hourlyRate: 1207.12,
      currency: '₹',
      totalWorkers: 8,
      assignedCount: 3,
      description: 'Takes orders, serves food and beverages, and attends to customers\' needs.',
    ),
    RoleData(
      roleName: 'Manager',
      hourlyRate: 2331.00,
      currency: '₹',
      totalWorkers: 2,
      assignedCount: 1,
      description: 'Oversees restaurant operations, manages staff, handles customer issues, and ensures smooth daily workflow.',
    ),
  ];

  int? _sortColumnIndex;
  bool _sortAscending = true;

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
                          const SizedBox(height: 8),
                          Text(
                            'Define roles, rates, and workforce requirements',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Assigned',
                          '${roles.fold<int>(0, (sum, role) => sum + role.assignedCount)}',
                          Icons.assignment_ind,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Avg Rate',
                          '₹${(roles.fold<double>(0, (sum, role) => sum + role.hourlyRate) / roles.length).toStringAsFixed(0)}',
                          Icons.currency_rupee,
                          Colors.purple,
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
                        ],
                      ),
                    ),
                    
                    // Table Content
                    Expanded(
                      child: filteredRoles.isEmpty
                          ? _buildEmptyState()
                          : SingleChildScrollView(
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
                                  DataColumn(
                                    label: const Text('Assigned'),
                                    onSort: (i, asc) => _sortBy((r) => r.assignedCount, i, asc),
                                    numeric: true,
                                  ),
                                  const DataColumn(label: Text('Description')),
                                  const DataColumn(label: Text('Actions')),
                                ],
                                rows: filteredRoles.map((role) {
                                  return DataRow(
                                    cells: [
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
                                      DataCell(
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${role.assignedCount}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '/ ${role.totalWorkers}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
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
    final assignedController = TextEditingController(text: existingRole?.assignedCount.toString() ?? '');
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
                              keyboardType: TextInputType.number,
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: assignedController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Currently Assigned',
                          prefixIcon: const Icon(Icons.assignment_ind),
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
                      onPressed: () {
                        final newRole = RoleData(
                          roleName: nameController.text.trim(),
                          hourlyRate: double.tryParse(rateController.text) ?? 0.0,
                          currency: '₹',
                          totalWorkers: int.tryParse(totalWorkersController.text) ?? 0,
                          assignedCount: int.tryParse(assignedController.text) ?? 0,
                          description: descriptionController.text.trim(),
                        );
                        
                        setState(() {
                          if (existingRole != null) {
                            final index = roles.indexOf(existingRole);
                            roles[index] = newRole;
                          } else {
                            roles.add(newRole);
                          }
                        });
                        
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete the "${role.roleName}" role?'),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone and will affect ${role.assignedCount} assigned workers.',
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
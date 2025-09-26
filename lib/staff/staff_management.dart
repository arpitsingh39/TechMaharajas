// lib/staff/staff management.dart
import 'package:flutter/material.dart';

class StaffMember {
  String name;
  String role;
  String contact;
  // Simple display string for demo (e.g., "Mon 09:00–13:00; Fri 14:00–20:00")
  String availability;
  int maxHours; // New field for max hours per week
  double hourlyRate; // New field for hourly rate
  
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
  final roles = <String>['Cashier', 'Cleaner', 'Chef', 'Server', 'Manager', 'Sales', 'Stock', 'Barista'];
  final List<StaffMember> staff = [
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
  Widget build(BuildContext context) {
    final filteredStaff = staff.where((s) =>
        s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        s.role.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

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
                          const SizedBox(height: 8),
                          Text(
                            'Manage your team members and their schedules',
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
                          onPressed: () async {
                            final created = await showDialog<StaffMember>(
                              context: context,
                              builder: (_) => _StaffEditorDialog(roles: roles),
                            );
                            if (created != null) {
                              setState(() => staff.add(created));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.person_add, size: 20),
                          label: const Text(
                            'Add Staff',
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
                          'Total Staff',
                          '${staff.length}',
                          Icons.people,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Active Roles',
                          '${staff.map((s) => s.role).toSet().length}',
                          Icons.work,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Avg Hours',
                          '${(staff.fold<int>(0, (sum, s) => sum + s.maxHours) / staff.length).toInt()}',
                          Icons.schedule,
                          Colors.orange,
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                        ],
                      ),
                    ),
                    
                    // Table Content
                    Expanded(
                      child: filteredStaff.isEmpty
                          ? _buildEmptyState()
                          : SingleChildScrollView(
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
                                    onSort: (i, asc) => _sortBy((s) => s.name, i, asc),
                                  ),
                                  DataColumn(
                                    label: const Text('Role'),
                                    onSort: (i, asc) => _sortBy((s) => s.role, i, asc),
                                  ),
                                  const DataColumn(label: Text('Availability')),
                                  const DataColumn(label: Text('Contact')),
                                  const DataColumn(label: Text('Max Hours')),
                                  const DataColumn(label: Text('Hourly Rate')),
                                  const DataColumn(label: Text('Actions')),
                                ],
                                rows: filteredStaff.map((s) {
                                  return DataRow(
                                    cells: [
                                      DataCell(
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 18,
                                              backgroundColor: _getRoleColor(s.role).withOpacity(0.2),
                                              child: Text(
                                                s.name.split(' ').map((e) => e[0]).join('').toUpperCase(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: _getRoleColor(s.role),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisAlignment: MainAxisAlignment.center,
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
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(s.role).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: _getRoleColor(s.role).withOpacity(0.3),
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
                                        SizedBox(
                                          width: 200,
                                          child: Text(
                                            s.availability,
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
                                          children: [
                                            Icon(Icons.phone, size: 14, color: Colors.grey[500]),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
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
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                tooltip: 'Edit',
                                                icon: Icon(Icons.edit, size: 18, color: Colors.blue[600]),
                                                onPressed: () async {
                                                  final updated = await showDialog<StaffMember>(
                                                    context: context,
                                                    builder: (_) => _StaffEditorDialog(
                                                      roles: roles,
                                                      existing: s,
                                                    ),
                                                  );
                                                  if (updated != null) {
                                                    setState(() {
                                                      s.name = updated.name;
                                                      s.role = updated.role;
                                                      s.contact = updated.contact;
                                                      s.availability = updated.availability;
                                                      s.maxHours = updated.maxHours;
                                                      s.hourlyRate = updated.hourlyRate;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.red.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                tooltip: 'Delete',
                                                icon: Icon(Icons.delete, size: 18, color: Colors.red[600]),
                                                onPressed: () => _showDeleteDialog(s),
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

  void _sortBy(Comparable Function(StaffMember) key, int columnIndex, bool ascending) {
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
  final hourlyRateController = TextEditingController();
  late String role;

  // Availability editor: choose days via chips and one common time range for simplicity.
  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<String> selected = {};
  TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 17, minute: 0);

  @override
  void initState() {
    super.initState();
    role = widget.roles.first;
    maxHoursController.text = '40';
    hourlyRateController.text = '1200.00';
    
    if (widget.existing != null) {
      name.text = widget.existing!.name;
      contact.text = widget.existing!.contact;
      role = widget.existing!.role;
      maxHoursController.text = widget.existing!.maxHours.toString();
      hourlyRateController.text = widget.existing!.hourlyRate.toStringAsFixed(2);
      
      // Best-effort parse: mark days present in the availability string.
      for (final d in days) {
        if (widget.existing!.availability.contains(d)) selected.add(d);
      }
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
                    widget.existing == null ? 'Add New Staff Member' : 'Edit Staff Member',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Basic Information Section
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
                          items: widget.roles.map((r) => DropdownMenuItem(
                            value: r,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(r),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(r),
                              ],
                            ),
                          )).toList(),
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
              
              // Work Information Section
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: hourlyRateController,
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
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Availability Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Availability',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'Select working days:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: days.map((d) {
                        final isSelected = selected.contains(d);
                        return FilterChip(
                          label: Text(d),
                          selected: isSelected,
                          onSelected: (v) => setState(() {
                            if (v) {
                              selected.add(d);
                            } else {
                              selected.remove(d);
                            }
                          }),
                          backgroundColor: Colors.white,
                          selectedColor: Colors.green.withOpacity(0.2),
                          checkmarkColor: Colors.green[700],
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.green[700] : Colors.grey[600],
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected ? Colors.green : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      'Working hours:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.access_time, color: Colors.green[600]),
                              title: Text(
                                'Start: ${start.format(context)}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              onTap: () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: start,
                                );
                                if (t != null) setState(() => start = t);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.access_time_filled, color: Colors.green[600]),
                              title: Text(
                                'End: ${end.format(context)}',
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                              onTap: () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: end,
                                );
                                if (t != null) setState(() => end = t);
                              },
                            ),
                          ),
                        ),
                      ],
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
                      final avail = selected.isEmpty
                          ? '—'
                          : selected.map((d) => '$d ${_fmt(start)}–${_fmt(end)}').join('; ');
                      final result = StaffMember(
                        name: name.text.trim(),
                        role: role,
                        contact: contact.text.trim(),
                        availability: avail,
                        maxHours: int.tryParse(maxHoursController.text) ?? 40,
                        hourlyRate: double.tryParse(hourlyRateController.text) ?? 1200.0,
                      );
                      Navigator.pop(context, result);
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

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
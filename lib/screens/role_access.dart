import 'package:flutter/material.dart';

class RoleAccessPage extends StatefulWidget {
  const RoleAccessPage({super.key});

  @override
  State<RoleAccessPage> createState() => _RoleAccessPageState();
}

class _RoleAccessPageState extends State<RoleAccessPage> {
  final List<Map<String, dynamic>> _roles = [
    {'role': 'Student', 'permissions': ['View Content', 'Take Exams']},
    {'role': 'Parent', 'permissions': ['View Reports', 'Monitor Progress']},
    {'role': 'School', 'permissions': ['Manage Students', 'View Analytics']},
    {'role': 'Admin', 'permissions': ['All Access']},
  ];
  final List<String> _allPermissions = [
    'View Content', 'Take Exams', 'View Reports', 'Monitor Progress',
    'Manage Students', 'View Analytics', 'All Access', 'Edit Content', 'Delete Content', 'Export Data'
  ];
  final List<String> _auditLog = [];
  int? _selectedRoleIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Role-Based Access'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Custom Role',
            onPressed: _showAddRoleDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manage Roles & Permissions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _roles.length,
                itemBuilder: (context, index) {
                  final role = _roles[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(Icons.person, color: _selectedRoleIndex == index ? Colors.blue : Colors.grey),
                      title: Text(role['role'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Wrap(
                        spacing: 6,
                        children: List<Widget>.from(role['permissions'].map<Widget>((p) => Chip(label: Text(p)))),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              setState(() {
                                _selectedRoleIndex = index;
                              });
                              _showEditPermissionsDialog(role, index);
                            },
                          ),
                          if (index >= 4) // Custom roles only
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  _auditLog.add('Deleted role: ${role['role']}');
                                  _roles.removeAt(index);
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ExpansionTile(
              title: const Text('Audit Log'),
              children: _auditLog.isEmpty
                  ? [const ListTile(title: Text('No changes yet.'))]
                  : _auditLog.map((log) => ListTile(title: Text(log))).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPermissionsDialog(Map<String, dynamic> role, int index) {
    final selected = Set<String>.from(role['permissions']);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Permissions for ${role['role']}'),
          content: SizedBox(
            width: 300,
            child: Wrap(
              spacing: 8,
              children: _allPermissions.map((perm) {
                return FilterChip(
                  label: Text(perm),
                  selected: selected.contains(perm),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        selected.add(perm);
                      } else {
                        selected.remove(perm);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  role['permissions'] = selected.toList();
                  _auditLog.add('Edited permissions for ${role['role']}');
                });
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showAddRoleDialog() {
    final TextEditingController roleController = TextEditingController();
    final selected = <String>{};
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Role'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roleController,
                decoration: const InputDecoration(labelText: 'Role Name'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: _allPermissions.map((perm) {
                  return FilterChip(
                    label: Text(perm),
                    selected: selected.contains(perm),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          selected.add(perm);
                        } else {
                          selected.remove(perm);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _roles.add({
                    'role': roleController.text,
                    'permissions': selected.toList(),
                  });
                  _auditLog.add('Added custom role: ${roleController.text}');
                });
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

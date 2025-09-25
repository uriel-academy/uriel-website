import 'package:flutter/material.dart';

class BulkStudentManagementPage extends StatefulWidget {
  const BulkStudentManagementPage({super.key});

  @override
  State<BulkStudentManagementPage> createState() => _BulkStudentManagementPageState();
}

class _BulkStudentManagementPageState extends State<BulkStudentManagementPage> {
  final List<Map<String, String>> students = [
    {'name': 'Ama Mensah', 'email': 'ama@school.com'},
    {'name': 'Kwame Boateng', 'email': 'kwame@school.com'},
    {'name': 'Esi Owusu', 'email': 'esi@school.com'},
  ];
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  void _addStudent() {
    if (nameController.text.isNotEmpty && emailController.text.isNotEmpty) {
      setState(() {
        students.add({'name': nameController.text, 'email': emailController.text});
        nameController.clear();
        emailController.clear();
      });
    }
  }

  void _removeStudent(int index) {
    setState(() {
      students.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Student Management'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Student', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: 'Name'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: emailController,
                    decoration: const InputDecoration(hintText: 'Email'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addStudent,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Student List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, i) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(students[i]['name']![0])),
                    title: Text(students[i]['name']!),
                    subtitle: Text(students[i]['email']!),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFD62828)),
                      onPressed: () => _removeStudent(i),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

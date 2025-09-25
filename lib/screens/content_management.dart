import 'package:flutter/material.dart';


class ContentManagementPage extends StatefulWidget {
  const ContentManagementPage({super.key});

  @override
  State<ContentManagementPage> createState() => _ContentManagementPageState();
}

class _ContentManagementPageState extends State<ContentManagementPage> {
  final List<Map<String, dynamic>> _contents = [
    {'title': 'Math Textbook', 'type': 'Textbook', 'status': 'Published', 'file': null},
    {'title': 'BECE Past Questions 2024', 'type': 'Past Questions', 'status': 'Draft', 'file': null},
    {'title': 'AI Revision Plan', 'type': 'AI Tool', 'status': 'Published', 'file': null},
    {'title': 'WASSCE Mock Exam', 'type': 'Mock Exam', 'status': 'Archived', 'file': null},
  ];
  final List<Map<String, dynamic>> _bulkImport = [];

  void _showEditContentDialog(int index) {
    final content = _contents[index];
    final TextEditingController titleController = TextEditingController(text: content['title']);
    String status = content['status'];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Content'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: status,
                items: ['Published', 'Draft', 'Archived']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) status = val;
                },
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.remove_red_eye),
                label: const Text('Preview'),
                onPressed: () {
                  _showPreviewDialog(content);
                },
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
                  content['title'] = titleController.text;
                  content['status'] = status;
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

  void _showAddContentDialog() {
    final TextEditingController titleController = TextEditingController();
    String type = 'Textbook';
    String status = 'Draft';
    dynamic file;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Content'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: type,
                items: ['Textbook', 'Past Questions', 'AI Tool', 'Mock Exam']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) type = val;
                },
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: status,
                items: ['Published', 'Draft', 'Archived']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) status = val;
                },
                decoration: const InputDecoration(labelText: 'Status'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('Upload File'),
                onPressed: () {
                  // Simulate file upload
                  setState(() {
                    file = 'mock_file.pdf';
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File uploaded (mock)!')),
                  );
                },
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
                  _contents.add({
                    'title': titleController.text,
                    'type': type,
                    'status': status,
                    'file': file,
                  });
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

  void _showPreviewDialog(Map<String, dynamic> content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Preview: ${content['title']}'),
          content: Text('Type: ${content['type']}\nStatus: ${content['status']}\nFile: ${content['file'] ?? 'No file'}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showBulkImportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Bulk Import'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.file_upload),
                label: const Text('Import File (mock)'),
                onPressed: () {
                  setState(() {
                    _bulkImport.addAll([
                      {'title': 'Imported Content 1', 'type': 'Textbook', 'status': 'Draft', 'file': 'import1.pdf'},
                      {'title': 'Imported Content 2', 'type': 'Past Questions', 'status': 'Published', 'file': 'import2.pdf'},
                    ]);
                    _contents.addAll(_bulkImport);
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bulk import completed (mock)!')),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.file_download),
                label: const Text('Export All (mock)'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exported all content (mock)!')),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Management'),
        backgroundColor: const Color(0xFF1A1E3F),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddContentDialog,
            tooltip: 'Add Content',
          ),
          IconButton(
            icon: const Icon(Icons.import_export),
            onPressed: _showBulkImportDialog,
            tooltip: 'Bulk Import/Export',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: _contents.length,
          itemBuilder: (context, index) {
            final content = _contents[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.book, color: content['status'] == 'Published' ? Colors.green : Colors.grey),
                title: Text(content['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${content['type']} • ${content['status']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye),
                      onPressed: () => _showPreviewDialog(content),
                      tooltip: 'Preview',
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditContentDialog(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _contents.removeAt(index);
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
    );
  }
}

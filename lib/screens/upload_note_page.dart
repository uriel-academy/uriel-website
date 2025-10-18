import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class UploadNotePage extends StatefulWidget {
  const UploadNotePage({super.key});

  @override
  State<UploadNotePage> createState() => _UploadNotePageState();
}

class _UploadNotePageState extends State<UploadNotePage> {
  final _titleCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  XFile? _pickedImage;
  Uint8List? _pickedBytes;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedImage = picked;
        _pickedBytes = bytes;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      final idToken = await user.getIdToken();

      final uri = Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/uploadNote');
      String? imageBase64;
      String fileName = '';
      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        _pickedBytes = bytes;
        imageBase64 = base64Encode(bytes);
        fileName = _pickedImage!.name;
      }

      final body = {
        'title': _titleCtrl.text,
        'subject': _subjectCtrl.text,
        'text': _textCtrl.text,
        if (imageBase64 != null) 'imageBase64': imageBase64,
        if (fileName.isNotEmpty) 'fileName': fileName,
      };

      final r = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken'
      }, body: jsonEncode(body));

      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        if (j['ok'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note uploaded')));
          Navigator.of(context).pop();
          return;
        }
      }

      throw Exception('Upload failed: ${r.statusCode} ${r.body}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subjectCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Note')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: _subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
            const SizedBox(height: 8),
            TextField(controller: _textCtrl, decoration: const InputDecoration(labelText: 'Note text'), maxLines: 8),
            const SizedBox(height: 12),
            if (_pickedBytes != null) Image.memory(_pickedBytes!, height: 160),
            Row(
              children: [
                ElevatedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo), label: const Text('Pick Image')),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const CircularProgressIndicator() : const Text('Upload'))),
              ],
            )
          ],
        ),
      ),
    );
  }
}

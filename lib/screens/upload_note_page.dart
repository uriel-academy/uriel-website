import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../widgets/uri_chat.dart';
import '../services/note_service.dart';

class UploadNotePage extends StatefulWidget {
  const UploadNotePage({super.key});

  @override
  State<UploadNotePage> createState() => _UploadNotePageState();
}

class _UploadNotePageState extends State<UploadNotePage> {
  final _titleCtrl = TextEditingController();
  final _textCtrl = TextEditingController();
  XFile? _pickedImage;
  Uint8List? _pickedBytes;
  bool _loading = false;
  String _selectedSubject = 'Mathematics'; // Default subject
  bool _isEditing = false;
  String? _noteId;

  List<String> _getSubjectOptions() {
    // Common subjects for Ghanaian education system
    return [
      'Mathematics',
      'English',
      'Integrated Science',
      'Social Studies',
      'Religious and Moral Education',
      'Ghanaian Language',
      'French',
      'ICT',
      'Creative Arts',
      'Other'
    ];
  }

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
      if (_isEditing && _noteId != null) {
        // Update existing note
        final updatedData = {
          'title': _titleCtrl.text,
          'subject': _selectedSubject,
          'text': _textCtrl.text,
          // Images are handled in updateNote to preserve existing ones
        };
        await NoteService.updateNote(_noteId!, updatedData);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Note updated successfully!',
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF2ECC71),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      // Create new note
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
        'subject': _selectedSubject,
        'text': _textCtrl.text,
        'authorName': user.displayName ?? 'Anonymous User',
        'authorId': user.uid,
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Note uploaded successfully!',
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF2ECC71),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
          Navigator.of(context).pop();
          return;
        }
      }

      throw Exception('Upload failed: ${r.statusCode} ${r.body}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFE74C3C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('noteId')) {
        _isEditing = true;
        _noteId = args['noteId'];
        _titleCtrl.text = args['title'] ?? '';
        _textCtrl.text = args['text'] ?? '';
        _selectedSubject = args['subject'] ?? 'Mathematics';
        // For images, we don't load them here as they are preserved in updateNote
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A1E3F)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Note' : 'Upload Note',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1E3F),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Your Knowledge',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: isMobile ? 28 : 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A1E3F),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Help fellow students by uploading your study notes, summaries, or visual aids. Every contribution makes a difference.',
                        style: GoogleFonts.montserrat(
                          fontSize: isMobile ? 16 : 18,
                          color: Colors.grey[600],
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                // Form section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title field
                      Text(
                        'Note Title',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1E3F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _titleCtrl,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: const Color(0xFF1A1E3F),
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., Quadratic Equations Summary',
                          hintStyle: GoogleFonts.montserrat(
                            color: Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Subject field
                      Text(
                        'Subject',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1E3F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _selectedSubject,
                        onChanged: (value) => setState(() => _selectedSubject = value!),
                        decoration: InputDecoration(
                          hintText: 'Select a subject',
                          hintStyle: GoogleFonts.montserrat(
                            color: Colors.grey[400],
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        dropdownColor: Colors.white,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: const Color(0xFF1A1E3F),
                        ),
                        items: _getSubjectOptions().map((subject) {
                          return DropdownMenuItem(
                            value: subject,
                            child: Text(subject),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Note content field
                      Text(
                        'Note Content',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1E3F),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _textCtrl,
                        maxLines: 8,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: const Color(0xFF1A1E3F),
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Write your notes here... You can include explanations, formulas, key points, or any helpful information.',
                          hintStyle: GoogleFonts.montserrat(
                            color: Colors.grey[400],
                            height: 1.5,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFE),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Image preview
                      if (_pickedBytes != null) ...[
                        Text(
                          'Attached Image',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1E3F),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: MemoryImage(_pickedBytes!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Action buttons
                      Row(
                        children: [
                          // Pick image button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: Icon(
                                _pickedBytes != null ? Icons.image : Icons.add_photo_alternate,
                                color: const Color(0xFF1A1E3F),
                              ),
                              label: Text(
                                _pickedBytes != null ? 'Change Image' : 'Add Image',
                                style: GoogleFonts.montserrat(
                                  color: const Color(0xFF1A1E3F),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(color: Color(0xFF1A1E3F), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Upload button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _loading ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2ECC71), // Uriel green
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                                  child: _loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      _isEditing ? 'Update Note' : 'Upload Note',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bottom spacing
                const SizedBox(height: 32),
              ],
            ),
          ),

          // URI Chat overlay
          Positioned(
            right: isMobile ? 16 : 24,
            bottom: isMobile ? 100 : 24,
            child: const UriChat(),
          ),
        ],
      ),
    );
  }
}

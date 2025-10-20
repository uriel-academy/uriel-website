import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/uri_chat.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSubject = 'All Subjects';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _getSubjectOptions() {
    // Common subjects for Ghanaian education system
    return [
      'All Subjects',
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

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 768;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and upload button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes Library',
                          style: GoogleFonts.montserrat(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1E3F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Browse, upload, and manage study notes (text, photo, mixed).',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isSmallScreen)
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed('/upload_note'),
                      icon: const Icon(Icons.add),
                      label: const Text('Upload Note'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71), // Uriel green
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
              if (isSmallScreen)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/upload_note'),
                    icon: const Icon(Icons.add),
                    label: const Text('Upload Note'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71), // Uriel green
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              // Search and Filter Card
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search & Filter',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
                      decoration: InputDecoration(
                        hintText: 'Search notes by title or content...',
                        hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFE),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Subject filter
                    DropdownButtonFormField<String>(
                      value: _selectedSubject,
                      onChanged: (value) => setState(() => _selectedSubject = value!),
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        labelStyle: GoogleFonts.montserrat(color: Colors.grey[600]),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFE),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      dropdownColor: Colors.white,
                      style: GoogleFonts.montserrat(color: const Color(0xFF1A1E3F)),
                      items: _getSubjectOptions().map((subject) {
                        return DropdownMenuItem(value: subject, child: Text(subject));
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Upload Notes Button - Centered and larger
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pushNamed('/upload_note'),
                        icon: const Icon(Icons.add, size: 20),
                        label: Text(
                          'Upload Notes',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71), // Uriel green
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          minimumSize: Size(
                            MediaQuery.of(context).size.width * 0.4, // 40% larger than default
                            56,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: const Color(0xFF2ECC71).withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Real-time list of user's notes with filtering
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notes')
                    .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data?.docs ?? [];

                  // Apply filters
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? '').toString().toLowerCase();
                    final subject = (data['subject'] ?? '').toString();
                    final text = (data['text'] ?? '').toString().toLowerCase();
                    final searchQuery = _searchController.text.toLowerCase();

                    // Subject filter
                    if (_selectedSubject != 'All Subjects' && subject != _selectedSubject) {
                      return false;
                    }

                    // Text search filter
                    if (searchQuery.isNotEmpty) {
                      if (!title.contains(searchQuery) && !text.contains(searchQuery)) {
                        return false;
                      }
                    }

                    return true;
                  }).toList();

                  if (filteredDocs.isEmpty) {
                    return Center(
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          Icon(Icons.menu_book, size: 72, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            docs.isEmpty ? 'No notes yet' : 'No notes match your search',
                            style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey[700])
                          ),
                          const SizedBox(height: 8),
                          Text(
                            docs.isEmpty
                                ? 'Upload text or photo notes to help students across Ghana.'
                                : 'Try adjusting your search or filters.',
                            style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredDocs.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, i) {
                      final d = filteredDocs[i].data() as Map<String, dynamic>;
                      final title = (d['title'] ?? '').toString();
                      final subject = (d['subject'] ?? '').toString();
                      final text = (d['text'] ?? '').toString();
                      final signedUrl = d['signedUrl'] as String?;
                      final filePath = d['filePath'] as String?;
                      final publicFileUrl = d['fileUrl'] as String?; // legacy public url

                      return ListTile(
                        leading: signedUrl != null
                            ? Image.network(signedUrl, width: 64, height: 64, fit: BoxFit.cover)
                            : (publicFileUrl != null
                                ? Image.network(publicFileUrl, width: 64, height: 64, fit: BoxFit.cover)
                                : (filePath != null ? Icon(Icons.image, size: 48, color: Colors.grey[400]) : Icon(Icons.article, size: 48, color: Colors.grey[400]))),
                        title: Text(
                          title.isNotEmpty ? title : 'Untitled',
                          style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w600)
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (subject.isNotEmpty)
                              Text(
                                subject,
                                style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[700])
                              ),
                            if (text.isNotEmpty)
                              Text(
                                text.length > 120 ? '${text.substring(0, 120)}…' : text,
                                style: GoogleFonts.montserrat(fontSize: 13)
                              )
                          ]
                        ),
                        onTap: () {
                          Navigator.of(context).pushNamed('/note', arguments: {'noteId': filteredDocs[i].id});
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),

        // URI Chat overlay
        Positioned(
          right: isSmallScreen ? 16 : 24,
          bottom: isSmallScreen ? 100 : 24,
          child: const UriChat(),
        ),
      ],
    );
  }
}

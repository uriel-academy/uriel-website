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

class _NotesTabState extends State<NotesTab> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSubject = 'All Subjects';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
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

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return const Color(0xFF2196F3);
      case 'english':
        return const Color(0xFF4CAF50);
      case 'integrated science':
        return const Color(0xFFFF9800);
      case 'social studies':
        return const Color(0xFF9C27B0);
      case 'religious and moral education':
        return const Color(0xFF795548);
      case 'ghanaian language':
        return const Color(0xFF607D8B);
      case 'creative arts':
        return const Color(0xFFE91E63);
      case 'french':
        return const Color(0xFF3F51B5);
      case 'ict':
        return const Color(0xFF009688);
      case 'other':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFF1A1E3F);
    }
  }

  Future<String?> _getCurrentUserSchool() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return data['school'] as String?;
      }
    } catch (e) {
      debugPrint('Error getting user school: $e');
    }
    return null;
  }

  Future<List<QueryDocumentSnapshot>> _filterNotes(
    List<QueryDocumentSnapshot> docs, 
    User? currentUser, 
    String? currentUserSchool
  ) async {
    final searchQuery = _searchController.text.toLowerCase();
    final filteredDocs = <QueryDocumentSnapshot>[];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final subject = (data['subject'] ?? '').toString();
      final text = (data['text'] ?? '').toString().toLowerCase();
      final userId = data['userId'] as String?;

      // Tab-based filtering
      if (_tabController.index == 1) { // My Notes
        if (userId != currentUser?.uid) continue;
      } else if (_tabController.index == 2) { // School Notes
        if (currentUserSchool == null || userId == null) continue;
        // For school notes, we need to check uploader's school
        try {
          final uploaderDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (uploaderDoc.exists) {
            final uploaderData = uploaderDoc.data() as Map<String, dynamic>;
            final uploaderSchool = uploaderData['school'] as String?;
            if (uploaderSchool != currentUserSchool) continue;
          } else {
            continue; // Can't verify school
          }
        } catch (e) {
          continue; // Error checking school
        }
      }
      // Tab 0 (All Notes) has no additional filtering

      // Subject filter
      if (_selectedSubject != 'All Subjects' && subject != _selectedSubject) {
        continue;
      }

      // Text search filter
      if (searchQuery.isNotEmpty) {
        if (!title.contains(searchQuery) && !text.contains(searchQuery)) {
          continue;
        }
      }

      filteredDocs.add(doc);
    }

    return filteredDocs;
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
              // Header with title only
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
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
                ],
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
              const SizedBox(height: 16),
              // Quick Access Tabs
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'All Notes'),
                    Tab(text: 'My Notes'),
                    Tab(text: 'School Notes'),
                  ],
                  labelColor: const Color(0xFFD62828),
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: const Color(0xFFD62828),
                  labelStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Real-time list of all notes with filtering
              FutureBuilder<String?>(
                future: _getCurrentUserSchool(),
                builder: (context, userSchoolSnapshot) {
                  final currentUserSchool = userSchoolSnapshot.data;
                  final currentUser = FirebaseAuth.instance.currentUser;

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('notes')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting || userSchoolSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];

                      // Apply filters
                      return FutureBuilder<List<QueryDocumentSnapshot>>(
                        future: _filterNotes(docs, currentUser, currentUserSchool),
                        builder: (context, filterSnapshot) {
                          if (filterSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          
                          final filteredDocs = filterSnapshot.data ?? [];

                          if (filteredDocs.isEmpty) {
                            return Center(
                              child: Column(
                                children: [
                                  const SizedBox(height: 40),
                                  Icon(Icons.menu_book, size: 72, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    docs.isEmpty ? 'No notes available' : 'No notes match your search',
                                    style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey[700])
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    docs.isEmpty
                                        ? 'Be the first to upload study notes and help fellow students!'
                                        : 'Try adjusting your search or filters.',
                                    style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            );
                          }

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isSmallScreen ? 1 : 2,
                              childAspectRatio: isSmallScreen ? 3.5 : 4.0,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, i) {
                              final d = filteredDocs[i].data() as Map<String, dynamic>;
                              final title = (d['title'] ?? '').toString();
                              final subject = (d['subject'] ?? '').toString();
                              final text = (d['text'] ?? '').toString();
                              final uploaderName = (d['uploaderName'] ?? 'Anonymous User').toString();
                              final signedUrl = d['signedUrl'] as String?;
                              final filePath = d['filePath'] as String?;
                              final publicFileUrl = d['fileUrl'] as String?; // legacy public url

                              return Card(
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    Navigator.of(context).pushNamed('/note', arguments: {'noteId': filteredDocs[i].id});
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Note preview/thumbnail
                                        Container(
                                          width: isSmallScreen ? 60 : 80,
                                          height: isSmallScreen ? 60 : 80,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            color: const Color(0xFFF8FAFE),
                                          ),
                                          child: signedUrl != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    signedUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        const Icon(Icons.image, color: Colors.grey),
                                                  ),
                                                )
                                              : (publicFileUrl != null
                                                  ? ClipRRect(
                                                      borderRadius: BorderRadius.circular(8),
                                                      child: Image.network(
                                                        publicFileUrl,
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) =>
                                                            const Icon(Icons.image, color: Colors.grey),
                                                      ),
                                                    )
                                                  : Icon(
                                                      filePath != null ? Icons.image : Icons.article,
                                                      size: isSmallScreen ? 24 : 32,
                                                      color: Colors.grey[400],
                                                    )),
                                        ),
                                        const SizedBox(width: 16),
                                        // Note details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Title
                                              Text(
                                                title.isNotEmpty ? title : 'Untitled',
                                                style: GoogleFonts.montserrat(
                                                  fontSize: isSmallScreen ? 16 : 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF1A1E3F),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              // Subject and uploader
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _getSubjectColor(subject).withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      subject.isNotEmpty ? subject : 'General',
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                        color: _getSubjectColor(subject),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'by $uploaderName',
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              // Preview text
                                              if (text.isNotEmpty)
                                                Text(
                                                  text.length > 100 ? '${text.substring(0, 100)}…' : text,
                                                  style: GoogleFonts.montserrat(
                                                    fontSize: 13,
                                                    color: Colors.grey[700],
                                                    height: 1.4,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                        // Action icon
                                        Icon(
                                          Icons.chevron_right,
                                          color: Colors.grey[400],
                                          size: isSmallScreen ? 20 : 24,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
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

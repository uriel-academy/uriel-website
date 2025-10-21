import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSubject = 'All Subjects';
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<String> _getSubjectOptions() => [
        'All Subjects',
        'Mathematics',
        'English',
        'Integrated Science',
        'Social Studies',
    'RME',
        'Ghanaian Language',
        'French',
        'ICT',
        'Creative Arts',
        'Other'
      ];

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
      case 'rme':
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

  /// Returns a subject-specific asset image path for note covers when
  /// the note has no network image. Returns null if no matching asset.
  String? _getCoverAssetForSubject(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('math')) return 'assets/notes_cover/mathematics_note_cover.png';
    if (s.contains('english')) return 'assets/notes_cover/english_note_cover.png';
    if (s.contains('integrated')) return 'assets/notes_cover/integrated_science_note_cover.png';
    if (s.contains('social')) return 'assets/notes_cover/social_studies_note_cover.png';
    if (s.contains('relig') || s == 'rme' || s.contains('rme')) return 'assets/notes_cover/rmw_note_cover.png';
    if (s.contains('ghanaian')) return 'assets/notes_cover/ghanaian_language_note_cover.png';
    if (s.contains('french')) return 'assets/notes_cover/french_note_cover.png';
    if (s.contains('ict')) return 'assets/notes_cover/ict_note_cover.png';
    if (s.contains('creative')) return 'assets/notes_cover/creative_arts_note_cover.png';
    return null;
  }

  Future<String?> _getCurrentUserSchool() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) return (userDoc.data() as Map<String, dynamic>)['school'] as String?;
    } catch (e) {
      debugPrint('Error getting user school: $e');
    }
    return null;
  }

  Future<List<QueryDocumentSnapshot>> _filterNotes(
    List<QueryDocumentSnapshot> docs,
    User? currentUser,
    String? currentUserSchool, {
    int? overrideTabIndex,
  }) async {
    final searchQuery = _searchController.text.toLowerCase();
    final filteredDocs = <QueryDocumentSnapshot>[];
    final tabIndex = overrideTabIndex ?? _tabController.index;

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final title = (data['title'] ?? '').toString().toLowerCase();
      final subject = (data['subject'] ?? '').toString();
      final text = (data['text'] ?? '').toString().toLowerCase();
      final userId = data['userId'] as String?;

      if (tabIndex == 1) {
        if (userId != currentUser?.uid) continue;
      } else if (tabIndex == 2) {
        if (currentUserSchool == null || userId == null) continue;
        try {
          final uploaderDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (uploaderDoc.exists) {
            final uploaderData = uploaderDoc.data() as Map<String, dynamic>;
            final uploaderSchool = uploaderData['school'] as String?;
            if (uploaderSchool != currentUserSchool) continue;
          } else {
            continue;
          }
        } catch (_) {
          continue;
        }
      }

      if (_selectedSubject != 'All Subjects' && subject != _selectedSubject) continue;
      if (searchQuery.isNotEmpty) {
        if (!title.contains(searchQuery) && !text.contains(searchQuery)) continue;
      }
      filteredDocs.add(doc);
    }

    return filteredDocs;
  }

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                  style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
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
                      const SizedBox(height: 12),
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedSubject,
                        onChanged: (v) => setState(() => _selectedSubject = v!),
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFE),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: _getSubjectOptions().map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(context).pushNamed('/upload_note'),
                          icon: const Icon(Icons.add, size: 20),
                          label: Text('Upload Notes', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2ECC71),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverTabBarDelegate(
            TabBar(
              controller: _tabController,
              tabs: const [Tab(text: 'All Notes'), Tab(text: 'My Notes'), Tab(text: 'School')],
              labelColor: const Color(0xFFD62828),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFD62828),
              labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
      ],
      body: FutureBuilder<String?>(
        future: _getCurrentUserSchool(),
        builder: (context, userSchoolSnapshot) {
          final currentUserSchool = userSchoolSnapshot.data;
          final currentUser = FirebaseAuth.instance.currentUser;

          return TabBarView(controller: _tabController, children: List.generate(3, (tabIndex) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('notes').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting || userSchoolSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final docs = snap.data?.docs ?? [];

                // Synchronous filtering for immediate responsiveness
                final searchQuery = _searchController.text.toLowerCase();
                final filteredDocs = <QueryDocumentSnapshot>[];
                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final subject = (data['subject'] ?? '').toString();
                  final text = (data['text'] ?? '').toString().toLowerCase();
                  final userId = data['userId'] as String?;

                  // Tab filtering
                  if (tabIndex == 1) {
                    if (userId != currentUser?.uid) continue;
                  } else if (tabIndex == 2) {
                    // Prefer a cached uploaderSchool on the note document if present
                    final uploaderSchool = (data['uploaderSchool'] ?? data['uploader_school']) as String?;
                    if (currentUserSchool == null) continue;
                    if (uploaderSchool == null) continue; // cannot determine, skip
                    if (uploaderSchool != currentUserSchool) continue;
                  }

                  // Subject filter
                  if (_selectedSubject != 'All Subjects' && subject != _selectedSubject) continue;

                  // Search filter
                  if (searchQuery.isNotEmpty && !title.contains(searchQuery) && !text.contains(searchQuery)) continue;

                  filteredDocs.add(doc);
                }

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sticky_note_2, size: 72, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(docs.isEmpty ? 'No notes available' : 'No notes match your search', style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey[700])),
                        const SizedBox(height: 8),
                        Text(docs.isEmpty ? 'Be the first to upload study notes!' : 'Try adjusting your search or filters.', style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.center),
                      ],
                    ),
                  );
                }

                final isSmall = MediaQuery.of(context).size.width < 768;
                final crossAxis = isSmall ? 2 : 4;
                final aspect = isSmall ? 0.65 : 0.75;

                return GridView.builder(
                  padding: EdgeInsets.all(isSmall ? 8 : 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxis, childAspectRatio: aspect, crossAxisSpacing: isSmall ? 10 : 16, mainAxisSpacing: isSmall ? 10 : 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, i) {
                    final d = filteredDocs[i].data() as Map<String, dynamic>;
                    final title = (d['title'] ?? '').toString();
                    final subject = (d['subject'] ?? '').toString();
                    final uploaderName = (d['uploaderName'] ?? 'Anonymous User').toString();
                    final signedUrl = d['signedUrl'] as String?;
                    final publicFileUrl = d['fileUrl'] as String?;
                    final userId = d['userId'] as String?;
                    final isUserNote = userId == currentUser?.uid;

                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).pushNamed('/note', arguments: {'noteId': filteredDocs[i].id}),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(
                            flex: 3,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: signedUrl != null
                                  ? Image.network(signedUrl, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(color: _getSubjectColor(subject)))
                                  : (publicFileUrl != null
                                      ? Image.network(publicFileUrl, fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, __, ___) => Container(color: _getSubjectColor(subject)))
                                      : (() {
                                          final asset = _getCoverAssetForSubject(subject);
                                          if (asset != null) {
                                            return Image.asset(asset, fit: BoxFit.cover, width: double.infinity);
                                          }
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_getSubjectColor(subject).withOpacity(0.7), _getSubjectColor(subject)]),
                                            ),
                                            child: Center(child: Icon(Icons.sticky_note_2, size: isSmall ? 36 : 44, color: Colors.white)),
                                          );
                                        }())),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: EdgeInsets.all(isSmall ? 8 : 12),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(title.isNotEmpty ? title : 'Untitled', style: GoogleFonts.montserrat(fontSize: isSmall ? 12 : 14, fontWeight: FontWeight.bold, color: const Color(0xFF1A1E3F)), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                  if (isUserNote) ...[
                                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editNote(filteredDocs[i]), iconSize: 18),
                                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteNote(filteredDocs[i]), iconSize: 18),
                                  ],
                                ]),
                                const SizedBox(height: 6),
                                Text('By $uploaderName', style: GoogleFonts.montserrat(fontSize: isSmall ? 10 : 12, color: Colors.grey[600])),
                                const Spacer(),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _getSubjectColor(subject).withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(subject.isNotEmpty ? subject : 'General', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _getSubjectColor(subject)))),
                                  const Icon(Icons.chevron_right, color: Color(0xFFD62828)),
                                ])
                              ]),
                            ),
                          ),
                        ]),
                      ),
                    );
                  },
                );
              },
            );
          }));
        },
      ),
    );
  }

  void _editNote(DocumentSnapshot noteDoc) {
    final data = noteDoc.data() as Map<String, dynamic>;
    Navigator.of(context).pushNamed('/upload_note', arguments: {
      'noteId': noteDoc.id,
      'title': data['title'] ?? '',
      'subject': data['subject'] ?? '',
      'text': data['text'] ?? '',
      'filePath': data['filePath'],
      'signedUrl': data['signedUrl'],
      'fileUrl': data['fileUrl'],
    });
  }

  void _deleteNote(DocumentSnapshot noteDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('notes').doc(noteDoc.id).delete();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note deleted successfully')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete note: $e')));
      }
    }
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverTabBarDelegate(this._tabBar);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(color: Colors.white, child: _tabBar);

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => oldDelegate._tabBar != _tabBar;
}

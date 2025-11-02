import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
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
  // Track which note thumbnails we've prefetched so we don't repeat work
  final Set<String> _prefetchedNoteIds = <String>{};

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
    String? currentUserSchool,
    int tabIndex,
    String searchQuery,
    String selectedSubject,
  ) async {
    final filteredDocs = <QueryDocumentSnapshot>[];
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

      if (selectedSubject != 'All Subjects' && subject != selectedSubject) continue;
      if (searchQuery.isNotEmpty) {
        if (!title.contains(searchQuery) && !text.contains(searchQuery)) continue;
      }
      filteredDocs.add(doc);
    }

    return filteredDocs;
  }

  Widget _buildNotesGrid(List<QueryDocumentSnapshot> filteredDocs, int tabIndex, User? currentUser, String? currentUserSchool, {bool showLoadMore = false}) {
    if (filteredDocs.isEmpty) {
      String message;
      String subMessage;
      IconData icon;
      if (tabIndex == 1) {
        message = 'No notes in your collection yet';
        subMessage = 'Upload notes or like notes from others to see them here.';
        icon = Icons.library_books;
      } else {
        message = 'No notes available';
        subMessage = 'Be the first to upload study notes!';
        icon = Icons.sticky_note_2;
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(message, style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Text(subMessage, style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final isSmall = MediaQuery.of(context).size.width < 768;
    final crossAxis = isSmall ? 2 : 4;
    final aspect = isSmall ? 0.65 : 0.75;

    // Start a non-blocking prefetch of the top thumbnails visible on screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startPrefetchIfNeeded(filteredDocs);
    });

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(isSmall ? 8 : 12),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: crossAxis, childAspectRatio: aspect, crossAxisSpacing: isSmall ? 10 : 16, mainAxisSpacing: isSmall ? 10 : 16),
              itemCount: filteredDocs.length,
      itemBuilder: (context, i) {
        final d = filteredDocs[i].data() as Map<String, dynamic>;
        final title = (d['title'] ?? '').toString();
        final subject = (d['subject'] ?? '').toString();
        final uploaderName = (d['authorName'] ?? 'Anonymous').toString();
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
                          child: NoteThumbnail(
                              noteId: filteredDocs[i].id,
                              signedUrl: signedUrl,
                              publicFileUrl: publicFileUrl,
                              filePath: d['filePath'] as String?,
                              subject: subject,
                              placeholderColor: _getSubjectColor(subject),
                              assetPath: _getCoverAssetForSubject(subject),
                            ),
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
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: _getSubjectColor(subject).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)), child: Text(subject.isNotEmpty ? subject : 'General', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w600, color: _getSubjectColor(subject)))),
                      const Icon(Icons.chevron_right, color: Color(0xFFD62828)),
                    ])
                  ]),
                ),
              ),
            ]),
          ),
        );
      },
            ),
          ),
          if (showLoadMore)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Showing first 100 notes. Use search or subject filter to narrow results.',
                style: GoogleFonts.montserrat(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  void _startPrefetchIfNeeded(List<QueryDocumentSnapshot> docs) {
    // Prefetch first N items only to avoid overloading the network
    const int maxToPrefetch = 12;
    final toPrefetch = <QueryDocumentSnapshot>[];
    for (final d in docs) {
      if (toPrefetch.length >= maxToPrefetch) break;
      if (!_prefetchedNoteIds.contains(d.id)) toPrefetch.add(d);
    }
    if (toPrefetch.isEmpty) return;
    // Run prefetch asynchronously and don't await from UI thread
    _prefetchThumbnails(toPrefetch);
  }

  Future<void> _prefetchThumbnails(List<QueryDocumentSnapshot> docs) async {
    // Limit concurrency to avoid spikes by batching
    const int concurrency = 3;
    final remaining = docs.where((d) => !_prefetchedNoteIds.contains(d.id)).toList();
    Future<void> prefetchOne(QueryDocumentSnapshot doc) async {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final filePath = data['filePath'] as String?;
        String? url;
        if (filePath != null && filePath.isNotEmpty) {
          try {
            url = await FirebaseStorage.instance.ref(filePath).getDownloadURL();
          } catch (_) {
            url = null;
          }
        }
        // If we still don't have a URL, try the callable (non-blocking)
        if ((url == null || url.isEmpty) && kIsWeb) {
          try {
            final callable = FirebaseFunctions.instance.httpsCallable('getNoteSignedUrlCallable');
            final resp = await callable.call(<String, dynamic>{'noteId': doc.id});
            final data = resp.data as Map<String, dynamic>;
            if (data['ok'] == true && data['signedUrl'] != null) url = data['signedUrl'] as String;
          } catch (_) {}
        }

        if (url != null && url.isNotEmpty) {
          try {
            await precacheImage(CachedNetworkImageProvider(url), context);
          } catch (_) {}
        }
      } catch (e) {
        // ignore per-item failures
      } finally {
        _prefetchedNoteIds.add(doc.id);
      }
    }

    for (var i = 0; i < remaining.length; i += concurrency) {
      final batch = remaining.skip(i).take(concurrency).toList();
      try {
        await Future.wait(batch.map((d) => prefetchOne(d)));
      } catch (_) {
        // ignore batch errors
      }
    }
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
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2)),
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

          return TabBarView(controller: _tabController, children: [
            // All Notes tab
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('notes').orderBy('createdAt', descending: true).limit(100).snapshots(),
              builder: (context, snap) => FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _filterNotes(snap.data?.docs ?? [], currentUser, currentUserSchool, 0, _searchController.text.toLowerCase(), _selectedSubject),
                builder: (context, filterSnap) {
                  if (snap.connectionState == ConnectionState.waiting || userSchoolSnapshot.connectionState == ConnectionState.waiting || filterSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final filteredDocs = filterSnap.data ?? [];
                  return _buildNotesGrid(filteredDocs, 0, currentUser, currentUserSchool, showLoadMore: (snap.data?.docs.length ?? 0) >= 100);
                }
              ),
            ),
            // My Notes tab (uploaded and liked notes)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('notes').orderBy('createdAt', descending: true).limit(100).snapshots(),
              builder: (context, notesSnap) => StreamBuilder<QuerySnapshot>(
                stream: currentUser != null ? FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('my_notes').orderBy('addedAt', descending: true).limit(100).snapshots() : const Stream.empty(),
                builder: (context, myNotesSnap) {
                  if (notesSnap.connectionState == ConnectionState.waiting || myNotesSnap.connectionState == ConnectionState.waiting || userSchoolSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final notesDocs = notesSnap.data?.docs ?? [];
                  final myNotesDocs = myNotesSnap.data?.docs ?? [];
                  final myNoteIds = myNotesDocs.map((d) => d['noteId'] as String?).where((id) => id != null).cast<String>().toSet();
                  final combinedDocs = notesDocs.where((doc) => (doc['userId'] as String?) == currentUser?.uid || myNoteIds.contains(doc.id)).toList();
                  // Apply search and subject filters
                  final searchQuery = _searchController.text.toLowerCase();
                  final selectedSubject = _selectedSubject;
                  final filteredDocs = combinedDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data['title'] ?? '').toString().toLowerCase();
                    final subject = (data['subject'] ?? '').toString();
                    final text = (data['text'] ?? '').toString().toLowerCase();
                    if (selectedSubject != 'All Subjects' && subject != selectedSubject) return false;
                    if (searchQuery.isNotEmpty && !title.contains(searchQuery) && !text.contains(searchQuery)) return false;
                    return true;
                  }).toList();
                  // Sort by createdAt descending
                  filteredDocs.sort((a, b) {
                    final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    return bTime.compareTo(aTime);
                  });
                  return _buildNotesGrid(filteredDocs, 1, currentUser, currentUserSchool, showLoadMore: (notesDocs.length >= 100 || myNotesDocs.length >= 100));
                }
              ),
            ),
            // School tab
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('notes').orderBy('createdAt', descending: true).limit(100).snapshots(),
              builder: (context, snap) => FutureBuilder<List<QueryDocumentSnapshot>>(
                future: _filterNotes(snap.data?.docs ?? [], currentUser, currentUserSchool, 2, _searchController.text.toLowerCase(), _selectedSubject),
                builder: (context, filterSnap) {
                  if (snap.connectionState == ConnectionState.waiting || userSchoolSnapshot.connectionState == ConnectionState.waiting || filterSnap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  final filteredDocs = filterSnap.data ?? [];
                  return _buildNotesGrid(filteredDocs, 2, currentUser, currentUserSchool, showLoadMore: (snap.data?.docs.length ?? 0) >= 100);
                }
              ),
            ),
          ]);
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

/// Small helper widget that displays a note thumbnail image.
///
/// Behavior:
/// - If `signedUrl` is provided, show it directly.
/// - Else if running on web, attempt to fetch a signed URL via the
///   `getNoteSignedUrlCallable` Cloud Function (requires user to be signed in).
/// - Else, fall back to `publicFileUrl`, then `assetPath`, then a gradient placeholder.
class NoteThumbnail extends StatefulWidget {
  final String noteId;
  final String? signedUrl;
  final String? publicFileUrl;
  final String? filePath;
  final String subject;
  final Color placeholderColor;
  final String? assetPath;

  const NoteThumbnail({
    Key? key,
    required this.noteId,
    this.signedUrl,
    this.publicFileUrl,
    this.filePath,
    required this.subject,
    required this.placeholderColor,
    this.assetPath,
  }) : super(key: key);

  @override
  State<NoteThumbnail> createState() => _NoteThumbnailState();
}

class _NoteThumbnailState extends State<NoteThumbnail> {
  String? _url;
  bool _loading = false;
  bool _fetchFailed = false;
  bool _needsAuth = false;
  Uint8List? _imageBytes;
  // Simple in-memory cache shared across instances to avoid refetching bytes
  static final Map<String, Uint8List> _inMemoryImageCache = <String, Uint8List>{};

  @override
  void initState() {
    super.initState();
    _url = widget.signedUrl;
    // If running on web and no signedUrl, try to fetch one
    if (_url == null && kIsWeb) {
      _fetchSignedUrl();
    }
  }

  Future<void> _fetchSignedUrl() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _fetchFailed = false;
      _needsAuth = false;
    });
    try {
      // Try Storage direct download URL first if filePath is available.
      if (widget.filePath != null && widget.filePath!.isNotEmpty) {
        try {
          final storageUrl = await FirebaseStorage.instance.ref(widget.filePath).getDownloadURL();
          if (storageUrl.isNotEmpty) {
            if (!mounted) return;
            setState(() => _url = storageUrl);
            // Prefetch into image cache for snappy display
            try {
              await precacheImage(CachedNetworkImageProvider(storageUrl), context);
            } catch (_) {}
            return;
          }
        } catch (e) {
          // ignore and fall back to callable
        }
      }

      // Fallback to Cloud Function to mint a signed URL for private files
      final callable = FirebaseFunctions.instance.httpsCallable('getNoteSignedUrlCallable');
      try {
        final resp = await callable.call(<String, dynamic>{'noteId': widget.noteId});
        final data = resp.data as Map<String, dynamic>;
        if (data['ok'] == true && data['signedUrl'] != null) {
          if (!mounted) return;
          setState(() => _url = data['signedUrl'] as String);
          return;
        }
      } catch (e) {
        // If callable failed due to unauthenticated user, mark needsAuth so UI can prompt sign-in.
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (mounted) setState(() => _needsAuth = true);
          return;
        }
        // Otherwise we'll attempt proxy fetch below; record failure state later if needed.
      }

      // As a last resort try the new noteImageProxy which requires Authorization.
      // This fetches raw bytes and we display them via MemoryImage. This works on
      // mobile and web and lets us include the Authorization header.
      if (widget.filePath != null && widget.filePath!.isNotEmpty) {
        try {
          // Check in-memory cache first
          if (_inMemoryImageCache.containsKey(widget.noteId)) {
            _imageBytes = _inMemoryImageCache[widget.noteId];
            if (!mounted) return;
            setState(() {});
            return;
          }

          final user = FirebaseAuth.instance.currentUser;
          final idToken = user == null ? null : await user.getIdToken();
          if (idToken != null) {
            const functionsBase = 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net';
            final proxyUrl = '$functionsBase/noteImageProxy?path=${Uri.encodeComponent(widget.filePath!)}';
            final resp = await http.get(Uri.parse(proxyUrl), headers: {'Authorization': 'Bearer $idToken'});
            if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
              _imageBytes = resp.bodyBytes;
              _inMemoryImageCache[widget.noteId] = _imageBytes!;
              if (!mounted) return;
              setState(() {});
              return;
            } else if (resp.statusCode == 401 || resp.statusCode == 403) {
              // Authorization required — prompt sign-in / permission
              if (mounted) setState(() => _needsAuth = true);
              return;
            } else {
              // mark as failed so UI can offer retry
              if (mounted) setState(() => _fetchFailed = true);
            }
          }
        } catch (e) {
          // ignore and fall back to publicFileUrl/asset
        }
      }
    } catch (e) {
      // ignore errors - fallback will be used
      if (mounted) setState(() => _fetchFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _retryFetch() {
    if (_loading) return;
    setState(() {
      _fetchFailed = false;
      _needsAuth = false;
    });
    _fetchSignedUrl();
  }

  @override
  Widget build(BuildContext context) {
    // Priority: memory bytes (proxy fetch) -> resolved URL (signed/public) -> asset -> placeholder
    Widget content;
    if (_imageBytes != null) {
      content = Image.memory(
        _imageBytes!,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        width: double.infinity,
      );
    } else {
      final urlToShow = _url ?? widget.publicFileUrl;
      if (urlToShow != null) {
        content = CachedNetworkImage(
          imageUrl: urlToShow,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          width: double.infinity,
          placeholder: (_, __) => Container(color: Colors.grey[200]),
          errorWidget: (_, __, ___) => _placeholder(),
        );
      } else if (widget.assetPath != null) {
        content = Image.asset(widget.assetPath!, fit: BoxFit.cover, alignment: Alignment.topCenter, width: double.infinity);
      } else {
        content = _placeholder();
      }
    }

    // Overlay badges for loading / auth required / retry
    return Stack(children: [
      Positioned.fill(child: content),
      Positioned(
        top: 6,
        right: 6,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _loading
              ? Container(
                  key: const ValueKey('loading'),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                  child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
                )
              : _needsAuth
                  ? InkWell(
                      key: const ValueKey('auth'),
                      onTap: () => Navigator.of(context).pushNamed('/signin'),
                      child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle), child: const Icon(Icons.lock, size: 16, color: Colors.white)),
                    )
                  : _fetchFailed
                      ? InkWell(
                          key: const ValueKey('retry'),
                          onTap: _retryFetch,
                          child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle), child: const Icon(Icons.refresh, size: 16, color: Colors.white)),
                        )
                      : const SizedBox.shrink(),
        ),
      ),
    ]);
  }

  Widget _placeholder() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [widget.placeholderColor.withValues(alpha: 0.7), widget.placeholderColor]),
        ),
        child: const Center(child: Icon(Icons.sticky_note_2, size: 40, color: Colors.white)),
      );
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

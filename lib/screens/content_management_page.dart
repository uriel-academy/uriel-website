import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'admin_question_management.dart';
import 'trivia_management_page.dart';
import 'notes_page.dart';

class ContentManagementPage extends StatefulWidget {
  const ContentManagementPage({Key? key}) : super(key: key);

  @override
  State<ContentManagementPage> createState() => _ContentManagementPageState();
}

class _ContentManagementPageState extends State<ContentManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  Map<String, int> _contentCounts = {};
  String _searchQuery = '';
  List<StreamSubscription<QuerySnapshot>>? _contentStreams;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startRealTimeContentMonitoring();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    // Auto-refresh every 3 minutes for updated counts
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      if (mounted) {
        _refreshContentCounts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _contentStreams?.forEach((sub) => sub.cancel());
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startRealTimeContentMonitoring() {
    setState(() => _isLoading = true);
    _refreshContentCounts();
  }

  Future<void> _refreshContentCounts() async {
    try {
      final results = await Future.wait([
        _firestore.collection('questions').count().get(),
        _firestore.collection('french_questions').count().get(),
        _firestore.collection('theoryQuestions').count().get(),
        _firestore.collection('textbooks').count().get(),
        _firestore.collection('storybooks').count().get(),
        _firestore.collection('notes').count().get(),
        _firestore.collection('trivia').count().get(),
        _firestore.collection('courses').count().get(),
        _firestore.collection('textbook_content').count().get(),
      ]);

      if (mounted) {
        setState(() {
          _contentCounts = {
            'questions': results[0].count ?? 0,
            'french_questions': results[1].count ?? 0,
            'theory_questions': results[2].count ?? 0,
            'textbooks': results[3].count ?? 0,
            'storybooks': results[4].count ?? 0,
            'notes': results[5].count ?? 0,
            'trivia': results[6].count ?? 0,
            'courses': results[7].count ?? 0,
            'textbook_content': results[8].count ?? 0,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing content counts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentItems = _getFilteredContentItems();
    final totalContent =
        _contentCounts.values.fold(0, (sum, count) => sum + count);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          // Header Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Content Management',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage all educational content across the platform',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search and Stats Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Bar
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: GoogleFonts.montserrat(fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Search content types...',
                              hintStyle: GoogleFonts.montserrat(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(Icons.search,
                                  color: Colors.grey[500], size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatChip(
                                'Total Items',
                                totalContent.toString(),
                                const Color(0xFF007AFF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatChip(
                                'Content Types',
                                contentItems.length.toString(),
                                const Color(0xFF34C759),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatChip(
                                'Questions',
                                (_contentCounts['questions'] ?? 0).toString(),
                                const Color(0xFFFF9500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content Grid
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF007AFF))),
            )
          else if (contentItems.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No content types found',
                      style: GoogleFonts.montserrat(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.of(context).size.width < 768
                      ? 1
                      : MediaQuery.of(context).size.width < 1200
                          ? 2
                          : 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _buildContentCard(contentItems[index]);
                  },
                  childCount: contentItems.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredContentItems() {
    final items = [
      {
        'title': 'BECE Questions',
        'subtitle': 'Multiple choice questions',
        'count': _contentCounts['questions'] ?? 0,
        'icon': Icons.quiz,
        'color': const Color(0xFF007AFF),
        'route': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminQuestionManagementPage(),
              ),
            ),
      },
      {
        'title': 'French Questions',
        'subtitle': 'French language MCQs',
        'count': _contentCounts['french_questions'] ?? 0,
        'icon': Icons.translate,
        'color': const Color(0xFF34C759),
        'route': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminQuestionManagementPage(),
              ),
            ),
      },
      {
        'title': 'Theory Questions',
        'subtitle': 'Essay and theory questions',
        'count': _contentCounts['theory_questions'] ?? 0,
        'icon': Icons.edit_note,
        'color': const Color(0xFFFF9500),
        'route': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AdminQuestionManagementPage(),
              ),
            ),
      },
      {
        'title': 'Textbooks',
        'subtitle': 'Educational textbooks',
        'count': _contentCounts['textbooks'] ?? 0,
        'icon': Icons.menu_book,
        'color': const Color(0xFFAF52DE),
        'route': () {},
      },
      {
        'title': 'Storybooks',
        'subtitle': 'Reading storybooks',
        'count': _contentCounts['storybooks'] ?? 0,
        'icon': Icons.auto_stories,
        'color': const Color(0xFFFF3B30),
        'route': () {},
      },
      {
        'title': 'Notes',
        'subtitle': 'Study notes and materials',
        'count': _contentCounts['notes'] ?? 0,
        'icon': Icons.note_alt,
        'color': const Color(0xFF5856D6),
        'route': () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotesTab()),
            ),
      },
      {
        'title': 'Trivia',
        'subtitle': 'Trivia challenges',
        'count': _contentCounts['trivia'] ?? 0,
        'icon': Icons.psychology,
        'color': const Color(0xFFFF2D55),
        'route': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TriviaManagementPage(),
              ),
            ),
      },
      {
        'title': 'Courses',
        'subtitle': 'Course curriculum',
        'count': _contentCounts['courses'] ?? 0,
        'icon': Icons.school,
        'color': const Color(0xFF30B0C7),
        'route': () {},
      },
      {
        'title': 'Textbook Content',
        'subtitle': 'Textbook pages and chapters',
        'count': _contentCounts['textbook_content'] ?? 0,
        'icon': Icons.book,
        'color': const Color(0xFFFF9500),
        'route': () {},
      },
    ];

    if (_searchQuery.isEmpty) {
      return items;
    }

    return items.where((item) {
      final title = item['title'].toString().toLowerCase();
      final subtitle = item['subtitle'].toString().toLowerCase();
      return title.contains(_searchQuery) || subtitle.contains(_searchQuery);
    }).toList();
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> content) {
    final count = content['count'] as int;
    final title = content['title'] as String;
    final subtitle = content['subtitle'] as String;
    final icon = content['icon'] as IconData;
    final color = content['color'] as Color;
    final route = content['route'] as VoidCallback;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: route,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _formatNumber(count),
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(Icons.arrow_forward, size: 18, color: color),
                    const SizedBox(width: 6),
                    Text(
                      'Manage',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class NotesTab extends StatelessWidget {
  const NotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Notes Management - Coming Soon'),
    );
  }
}

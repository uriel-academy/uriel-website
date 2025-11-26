import 'package:flutter/material.dart';
import 'package:uriel_mainapp/services/english_textbook_service.dart';
import 'package:uriel_mainapp/screens/english_textbook_reader_page.dart';

class EnglishTextbooksLibraryPage extends StatefulWidget {
  const EnglishTextbooksLibraryPage({super.key});

  @override
  State<EnglishTextbooksLibraryPage> createState() => _EnglishTextbooksLibraryPageState();
}

class _EnglishTextbooksLibraryPageState extends State<EnglishTextbooksLibraryPage> {
  final _service = EnglishTextbookService();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _textbooks = [];
  final Map<String, Map<String, dynamic>> _progressMap = {};

  @override
  void initState() {
    super.initState();
    _loadTextbooks();
  }

  Future<void> _loadTextbooks() async {
    setState(() => _isLoading = true);

    try {
      _textbooks = await _service.getAllTextbooks();
      
      // Load progress for each textbook
      for (final textbook in _textbooks) {
        final progress = await _service.getUserProgress(textbook['id']);
        _progressMap[textbook['id']] = progress;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading textbooks: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double _getProgress(String textbookId) {
    final progress = _progressMap[textbookId];
    if (progress == null) return 0.0;

    final completedSections = (progress['completedSections'] ?? []).length;
    final textbook = _textbooks.firstWhere((t) => t['id'] == textbookId);
    final totalSections = textbook['totalSections'] ?? 1;
    
    return completedSections / totalSections;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('English Textbooks'),
        backgroundColor: const Color(0xFF1A1E3F),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_textbooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              'No textbooks available yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact your administrator to generate textbooks',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Header
        const Text(
          'Interactive English Textbooks',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1E3F),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Comprehensive BECE-aligned English Language course for JHS students',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // Textbook cards
        ..._textbooks.map((textbook) => _buildTextbookCard(textbook)),
      ],
    );
  }

  Widget _buildTextbookCard(Map<String, dynamic> textbook) {
    final textbookId = textbook['id'];
    final progress = _getProgress(textbookId);
    final progressPercent = (progress * 100).toInt();
    final userProgress = _progressMap[textbookId] ?? {};
    final totalXP = userProgress['totalXP'] ?? 0;
    final isComplete = userProgress['yearComplete'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnglishTextbookReaderPage(
                year: textbook['year'],
                textbookId: textbookId,
              ),
            ),
          ).then((_) => _loadTextbooks());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD62828).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.menu_book,
                      size: 40,
                      color: Color(0xFFD62828),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textbook['title'] ?? 'English Textbook',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1E3F),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          textbook['year'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isComplete)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Complete',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Stats
              Row(
                children: [
                  _buildStat(
                    Icons.article,
                    '${textbook['totalChapters'] ?? 0}',
                    'Chapters',
                  ),
                  const SizedBox(width: 24),
                  _buildStat(
                    Icons.layers,
                    '${textbook['totalSections'] ?? 0}',
                    'Sections',
                  ),
                  const SizedBox(width: 24),
                  _buildStat(
                    Icons.quiz,
                    '${textbook['totalQuestions'] ?? 0}',
                    'Questions',
                  ),
                  const SizedBox(width: 24),
                  _buildStat(
                    Icons.stars,
                    '$totalXP',
                    'XP Earned',
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Progress bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        '$progressPercent%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD62828),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFD62828),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EnglishTextbookReaderPage(
                          year: textbook['year'],
                          textbookId: textbookId,
                        ),
                      ),
                    ).then((_) => _loadTextbooks());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD62828),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    progress > 0 ? 'Continue Reading' : 'Start Reading',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: const Color(0xFFD62828)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1E3F),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

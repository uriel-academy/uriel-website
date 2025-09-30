import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/storage_service.dart';

class StorageContentTab extends StatefulWidget {
  const StorageContentTab({Key? key}) : super(key: key);

  @override
  State<StorageContentTab> createState() => _StorageContentTabState();
}

class _StorageContentTabState extends State<StorageContentTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PastQuestion> _beceRmeQuestions = [];
  List<StorageItem> _triviaContent = [];
  bool _isLoadingBece = false;
  bool _isLoadingTrivia = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBECERmeContent();
    _loadTriviaContent();
  }

  Future<void> _loadBECERmeContent() async {
    setState(() => _isLoadingBece = true);
    try {
      // First, list all available folders for debugging
      final folders = await StorageService.listAllStorageFolders();
      print('Available storage folders: $folders');
      
      final questions = await StorageService.getBECERMEQuestions();
      setState(() {
        _beceRmeQuestions = questions;
        _isLoadingBece = false;
      });
      
      if (questions.isEmpty) {
        _showErrorSnackBar('No RME questions found. Available folders: ${folders.join(", ")}');
      }
    } catch (e) {
      setState(() => _isLoadingBece = false);
      _showErrorSnackBar('Failed to load BECE RME content: $e');
    }
  }

  Future<void> _loadTriviaContent() async {
    setState(() => _isLoadingTrivia = true);
    try {
      // First, list all available folders for debugging  
      final folders = await StorageService.listAllStorageFolders();
      print('Available storage folders: $folders');
      
      final content = await _getTriviaFromStorage();
      setState(() {
        _triviaContent = content;
        _isLoadingTrivia = false;
      });
      
      if (content.isEmpty) {
        _showErrorSnackBar('No trivia content found. Available folders: ${folders.join(", ")}');
      }
    } catch (e) {
      setState(() => _isLoadingTrivia = false);
      _showErrorSnackBar('Failed to load trivia content: $e');
    }
  }

  Future<List<StorageItem>> _getTriviaFromStorage() async {
    try {
      final ListResult result = await FirebaseStorage.instance.ref('trivia').listAll();
      List<StorageItem> items = [];
      
      for (var item in result.items) {
        final String downloadUrl = await item.getDownloadURL();
        final FullMetadata metadata = await item.getMetadata();
        
        items.add(StorageItem(
          name: item.name,
          downloadUrl: downloadUrl,
          size: metadata.size ?? 0,
          contentType: metadata.contentType ?? 'unknown',
          timeCreated: metadata.timeCreated ?? DateTime.now(),
        ));
      }
      
      return items;
    } catch (e) {
      print('Error fetching trivia content: $e');
      return [];
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Firebase Storage Content',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'BECE RME Questions'),
            Tab(text: 'Trivia Content'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBECERmeTab(),
          _buildTriviaTab(),
        ],
      ),
    );
  }

  Widget _buildBECERmeTab() {
    return RefreshIndicator(
      onRefresh: _loadBECERmeContent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'BECE Religious & Moral Education',
              'Past questions and answers from Firebase Storage',
              Icons.book,
              const Color(0xFF2E7D32),
            ),
            const SizedBox(height: 16),
            
            // Statistics Card
            _buildStatsCard(
              'RME Questions',
              _beceRmeQuestions.length,
              Icons.quiz,
              Colors.green,
            ),
            
            const SizedBox(height: 16),
            
            // Questions List
            Expanded(
              child: _isLoadingBece
                  ? const Center(child: CircularProgressIndicator())
                  : _beceRmeQuestions.isEmpty
                      ? _buildEmptyState('No BECE RME questions found in storage')
                      : ListView.builder(
                          itemCount: _beceRmeQuestions.length,
                          itemBuilder: (context, index) {
                            final question = _beceRmeQuestions[index];
                            return _buildQuestionCard(question);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriviaTab() {
    return RefreshIndicator(
      onRefresh: _loadTriviaContent,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Trivia Content',
              'Trivia questions and answers from Firebase Storage',
              Icons.psychology,
              const Color(0xFF9C27B0),
            ),
            const SizedBox(height: 16),
            
            // Statistics Card
            _buildStatsCard(
              'Trivia Files',
              _triviaContent.length,
              Icons.file_copy,
              Colors.purple,
            ),
            
            const SizedBox(height: 16),
            
            // Trivia Content List
            Expanded(
              child: _isLoadingTrivia
                  ? const Center(child: CircularProgressIndicator())
                  : _triviaContent.isEmpty
                      ? _buildEmptyState('No trivia content found in storage')
                      : ListView.builder(
                          itemCount: _triviaContent.length,
                          itemBuilder: (context, index) {
                            final item = _triviaContent[index];
                            return _buildTriviaCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(String title, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(PastQuestion question) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question.title,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    question.year,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.subject, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  question.subject,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.storage, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  question.formattedFileSize,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadFile(question.downloadUrl, question.title),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _previewFile(question.downloadUrl),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E7D32),
                      side: const BorderSide(color: Color(0xFF2E7D32)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriviaCard(StorageItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1E3F),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.contentType,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9C27B0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDate(item.timeCreated),
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.storage, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatFileSize(item.size),
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadFile(item.downloadUrl, item.name),
                    icon: const Icon(Icons.download),
                    label: const Text('Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _previewFile(item.downloadUrl),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Preview'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9C27B0),
                      side: const BorderSide(color: Color(0xFF9C27B0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              _loadBECERmeContent();
              _loadTriviaContent();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        _showErrorSnackBar('Could not download file');
      }
    } catch (e) {
      _showErrorSnackBar('Error downloading file: $e');
    }
  }

  Future<void> _previewFile(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.inAppWebView);
      } else {
        _showErrorSnackBar('Could not preview file');
      }
    } catch (e) {
      _showErrorSnackBar('Error previewing file: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Storage Item Model
class StorageItem {
  final String name;
  final String downloadUrl;
  final int size;
  final String contentType;
  final DateTime timeCreated;

  StorageItem({
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.contentType,
    required this.timeCreated,
  });
}
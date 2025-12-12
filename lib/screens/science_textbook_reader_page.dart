import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/science_textbook_service.dart';

/// Reader page for Social Studies and RME textbooks
/// Displays chapters, sections, and embedded questions
class ScienceTextbookReaderPage extends StatefulWidget {
  final String textbookId;
  final String subject;
  final String year;

  const ScienceTextbookReaderPage({
    super.key,
    required this.textbookId,
    required this.subject,
    required this.year,
  });

  @override
  State<ScienceTextbookReaderPage> createState() => _ScienceTextbookReaderPageState();
}

class _ScienceTextbookReaderPageState extends State<ScienceTextbookReaderPage> {
  final ScienceTextbookService _service = ScienceTextbookService();
  
  List<Map<String, dynamic>> chapters = [];
  Map<String, List<Map<String, dynamic>>> sectionsMap = {};
  Map<String, dynamic>? currentSection;
  String? currentChapterId;
  String? currentSectionId;
  
  bool isLoading = true;
  bool isLoadingSection = false;
  bool showingQuestions = false;
  int selectedChapterIndex = 0;
  int selectedSectionIndex = 0;
  
  // Progress tracking
  Map<String, dynamic> userProgress = {};
  Set<String> completedSections = {};
  int totalXP = 0;
  
  // Answer tracking
  final Map<String, String> _selectedAnswers = {};
  final Map<String, bool> _submittedAnswers = {};

  @override
  void initState() {
    super.initState();
    _loadTextbook();
  }

  Future<void> _loadTextbook() async {
    setState(() => isLoading = true);
    try {
      // Load chapters
      chapters = await _service.getChapters(widget.textbookId);
      debugPrint('📚 Loaded ${chapters.length} chapters for ${widget.textbookId}');
      
      // Load sections for each chapter
      for (final chapter in chapters) {
        final chapterId = chapter['id'] as String;
        final sections = await _service.getSections(widget.textbookId, chapterId);
        sectionsMap[chapterId] = sections;
        debugPrint('  📖 Chapter ${chapter['chapterNumber']}: ${sections.length} sections');
      }
      
      // Load user progress
      userProgress = await _service.getUserProgress(widget.textbookId);
      completedSections = Set<String>.from(userProgress['completedSections'] ?? []);
      totalXP = userProgress['totalXP'] as int? ?? 0;
      
      // Load first section
      if (chapters.isNotEmpty) {
        final firstChapterId = chapters[0]['id'] as String;
        currentChapterId = firstChapterId;
        if (sectionsMap[firstChapterId]?.isNotEmpty ?? false) {
          currentSectionId = sectionsMap[firstChapterId]![0]['id'] as String;
          await _loadSection(firstChapterId, currentSectionId!);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading textbook: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadSection(String chapterId, String sectionId) async {
    setState(() {
      isLoadingSection = true;
      showingQuestions = false; // Reset quiz view when loading new section
    });
    try {
      // Convert string IDs to int chapter/section numbers
      final chapterNum = int.tryParse(chapterId.replaceAll(RegExp(r'\D'), '')) ?? 1;
      final sectionNum = int.tryParse(sectionId.replaceAll(RegExp(r'\D'), '')) ?? 1;
      currentSection = await _service.getSection(widget.textbookId, chapterNum, sectionNum);
      currentChapterId = chapterId;
      currentSectionId = sectionId;
      
      // Find indices for navigation
      for (int i = 0; i < chapters.length; i++) {
        if (chapters[i]['id'] == chapterId) {
          selectedChapterIndex = i;
          final sections = sectionsMap[chapterId] ?? [];
          for (int j = 0; j < sections.length; j++) {
            if (sections[j]['id'] == sectionId) {
              selectedSectionIndex = j;
              break;
            }
          }
          break;
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading section: $e');
    } finally {
      setState(() => isLoadingSection = false);
    }
  }

  Future<void> _markSectionComplete() async {
    if (currentSectionId == null) return;
    
    final xpReward = currentSection?['xpReward'] as int? ?? 50;
    final chapterNum = int.tryParse(currentChapterId!.replaceAll(RegExp(r'\D'), '')) ?? 1;
    final sectionNum = int.tryParse(currentSectionId!.replaceAll(RegExp(r'\D'), '')) ?? 1;
    await _service.completeSection(
      textbookId: widget.textbookId,
      chapterNumber: chapterNum,
      sectionNumber: sectionNum,
      xpReward: xpReward,
    );
    
    setState(() {
      completedSections.add(currentSectionId!);
      totalXP += xpReward;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Section complete! +$xpReward XP'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _navigateToNextSection() {
    final currentSections = sectionsMap[currentChapterId] ?? [];
    
    if (selectedSectionIndex < currentSections.length - 1) {
      // Next section in same chapter
      final nextSection = currentSections[selectedSectionIndex + 1];
      _loadSection(currentChapterId!, nextSection['id'] as String);
    } else if (selectedChapterIndex < chapters.length - 1) {
      // First section of next chapter
      final nextChapter = chapters[selectedChapterIndex + 1];
      final nextChapterId = nextChapter['id'] as String;
      final nextSections = sectionsMap[nextChapterId] ?? [];
      if (nextSections.isNotEmpty) {
        _loadSection(nextChapterId, nextSections[0]['id'] as String);
      }
    }
  }

  void _navigateToPreviousSection() {
    if (selectedSectionIndex > 0) {
      // Previous section in same chapter
      final currentSections = sectionsMap[currentChapterId] ?? [];
      final prevSection = currentSections[selectedSectionIndex - 1];
      _loadSection(currentChapterId!, prevSection['id'] as String);
    } else if (selectedChapterIndex > 0) {
      // Last section of previous chapter
      final prevChapter = chapters[selectedChapterIndex - 1];
      final prevChapterId = prevChapter['id'] as String;
      final prevSections = sectionsMap[prevChapterId] ?? [];
      if (prevSections.isNotEmpty) {
        _loadSection(prevChapterId, prevSections.last['id'] as String);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    // Get subject color
    final subjectColor = widget.subject.toLowerCase().contains('social')
        ? const Color(0xFF9C27B0)
        : const Color(0xFF795548);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1E3F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subject,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            Text(
              widget.year,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          // XP display
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, size: 18, color: Colors.amber),
                const SizedBox(width: 4),
                Text(
                  '$totalXP XP',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD62828)),
              ),
            )
          : isMobile
              ? _buildMobileLayout(subjectColor)
              : _buildDesktopLayout(subjectColor),
      bottomNavigationBar: isMobile && !isLoading
          ? _buildMobileBottomNav(subjectColor)
          : null,
    );
  }

  Widget _buildMobileLayout(Color subjectColor) {
    return Column(
      children: [
        // Chapter/Section selector
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _buildChapterDropdown(subjectColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSectionDropdown(subjectColor),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: isLoadingSection
              ? const Center(child: CircularProgressIndicator())
              : _buildSectionContent(subjectColor),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(Color subjectColor) {
    return Row(
      children: [
        // Sidebar with chapters and sections
        Container(
          width: 300,
          color: Colors.white,
          child: Column(
            children: [
              // Progress header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828).withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Progress',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _calculateOverallProgress(),
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD62828)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${((_calculateOverallProgress()) * 100).toInt()}% complete',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Chapters list
              Expanded(
                child: ListView.builder(
                  itemCount: chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = chapters[index];
                    final chapterId = chapter['id'] as String;
                    final sections = sectionsMap[chapterId] ?? [];
                    final isExpanded = chapterId == currentChapterId;
                    
                    return ExpansionTile(
                      initiallyExpanded: isExpanded,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isExpanded ? const Color(0xFFD62828) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${chapter['chapterNumber']}',
                            style: GoogleFonts.montserrat(
                              color: isExpanded ? Colors.white : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        chapter['title'] as String? ?? 'Chapter ${index + 1}',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: isExpanded ? FontWeight.bold : FontWeight.w500,
                          color: const Color(0xFF1A1E3F),
                        ),
                      ),
                      children: sections.map((section) {
                        final sectionId = section['id'] as String;
                        final isCurrentSection = sectionId == currentSectionId;
                        final isComplete = completedSections.contains(sectionId);
                        
                        return ListTile(
                          contentPadding: const EdgeInsets.only(left: 56, right: 16),
                          leading: Icon(
                            isComplete ? Icons.check_circle : Icons.circle_outlined,
                            size: 18,
                            color: isComplete ? Colors.green : Colors.grey,
                          ),
                          title: Text(
                            section['title'] as String? ?? 'Section',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: isCurrentSection ? FontWeight.bold : FontWeight.normal,
                              color: isCurrentSection ? const Color(0xFFD62828) : const Color(0xFF1A1E3F),
                            ),
                          ),
                          selected: isCurrentSection,
                          selectedTileColor: const Color(0xFFD62828).withOpacity(0.1),
                          onTap: () => _loadSection(chapterId, sectionId),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Main content area
        Expanded(
          child: isLoadingSection
              ? const Center(child: CircularProgressIndicator())
              : _buildSectionContent(subjectColor),
        ),
      ],
    );
  }

  Widget _buildChapterDropdown(Color subjectColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedChapterIndex,
          isExpanded: true,
          items: chapters.asMap().entries.map((entry) {
            return DropdownMenuItem<int>(
              value: entry.key,
              child: Text(
                'Ch ${entry.value['chapterNumber']}: ${entry.value['title']}',
                style: GoogleFonts.montserrat(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (index) {
            if (index != null) {
              final chapterId = chapters[index]['id'] as String;
              final sections = sectionsMap[chapterId] ?? [];
              if (sections.isNotEmpty) {
                _loadSection(chapterId, sections[0]['id'] as String);
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildSectionDropdown(Color subjectColor) {
    final currentSections = sectionsMap[currentChapterId] ?? [];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedSectionIndex < currentSections.length ? selectedSectionIndex : 0,
          isExpanded: true,
          items: currentSections.asMap().entries.map((entry) {
            final isComplete = completedSections.contains(entry.value['id']);
            return DropdownMenuItem<int>(
              value: entry.key,
              child: Row(
                children: [
                  if (isComplete)
                    const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  if (isComplete) const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      entry.value['title'] as String? ?? 'Section ${entry.key + 1}',
                      style: GoogleFonts.montserrat(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (index) {
            if (index != null && currentChapterId != null) {
              _loadSection(currentChapterId!, currentSections[index]['id'] as String);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSectionContent(Color subjectColor) {
    if (currentSection == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Select a section to start reading',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    final content = currentSection!['content'] as String? ?? '';
    final title = currentSection!['title'] as String? ?? 'Section';
    final questions = currentSection!['questions'] as List? ?? [];
    final isComplete = completedSections.contains(currentSectionId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD62828).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Chapter ${selectedChapterIndex + 1} • Section ${selectedSectionIndex + 1}',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFD62828),
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              'Completed',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1A1E3F),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Markdown content
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: MarkdownBody(
              data: content,
              styleSheet: MarkdownStyleSheet(
                h1: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
                h2: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
                h3: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
                p: GoogleFonts.montserrat(
                  fontSize: 16,
                  height: 1.7,
                  color: const Color(0xFF1A1E3F),
                ),
                listBullet: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: const Color(0xFF1A1E3F),
                ),
                tableHead: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                tableBody: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: const Color(0xFF1A1E3F),
                ),
                tableBorder: TableBorder.all(color: Colors.grey[300]!),
                blockquoteDecoration: BoxDecoration(
                  color: subjectColor.withOpacity(0.1),
                  border: Border(
                    left: BorderSide(color: subjectColor, width: 4),
                  ),
                ),
                code: GoogleFonts.firaCode(
                  fontSize: 14,
                  backgroundColor: Colors.grey[100],
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          
          // Take Section Quiz button
          if (questions.isNotEmpty && !showingQuestions) ...[
            const SizedBox(height: 32),
            _buildTakeQuizButton(questions, subjectColor),
          ],
          
          // Questions section (shown after clicking Take Quiz)
          if (questions.isNotEmpty && showingQuestions) ...[
            const SizedBox(height: 24),
            _buildQuestionsSection(questions, subjectColor),
          ],
          
          // Complete section button
          if (!isComplete) ...[
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _markSectionComplete,
                icon: const Icon(Icons.check_circle),
                label: Text(
                  'Mark Section Complete (+${currentSection?['xpReward'] ?? 50} XP)',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: subjectColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
          ],
          
          // Navigation buttons (desktop)
          if (MediaQuery.of(context).size.width >= 768) ...[
            const SizedBox(height: 32),
            _buildNavigationButtons(subjectColor),
          ],
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTakeQuizButton(List questions, Color subjectColor) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final totalXP = questions.fold<int>(0, (sum, q) => sum + ((q as Map)['xpValue'] as int? ?? 10));
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD62828).withOpacity(0.1),
            const Color(0xFFD62828).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD62828).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD62828),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.quiz,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready to Test Your Knowledge?',
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1E3F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${questions.length} questions • Earn up to $totalXP XP',
                      style: GoogleFonts.montserrat(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() => showingQuestions = true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: isMobile ? 14 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Take Section Quiz',
                style: GoogleFonts.montserrat(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionsSection(List questions, Color subjectColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD62828).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz, color: Color(0xFFD62828)),
              const SizedBox(width: 8),
              Text(
                'Section Quiz',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1E3F),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() => showingQuestions = false);
                },
                icon: const Icon(Icons.arrow_back, size: 18),
                label: Text(
                  'Back to Content',
                  style: GoogleFonts.montserrat(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD62828),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${questions.length} questions',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.amber[700],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...questions.asMap().entries.map((entry) {
            final q = entry.value as Map<String, dynamic>;
            return _buildQuestionCard(entry.key + 1, q, subjectColor);
          }),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int number, Map<String, dynamic> question, Color subjectColor) {
    final questionText = (question['questionText'] ?? question['question']) as String? ?? '';
    final options = question['options'] as Map<String, dynamic>? ?? {};
    final correctAnswer = question['correctAnswer'] as String? ?? 'A';
    final explanation = question['explanation'] as String? ?? '';
    final xpValue = (question['xpValue'] ?? question['xpReward']) as int? ?? 10;
    final questionId = question['id'] as String? ?? 'q$number';
    
    final isSubmitted = _submittedAnswers.containsKey(questionId);
    final isCorrect = _submittedAnswers[questionId] ?? false;
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 20),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD62828), Color(0xFFB71C1C)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Q$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.orange[200]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.stars,
                        size: 16,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '+$xpValue XP',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSubmitted) ...[
                  const SizedBox(width: 8),
                  Icon(
                    isCorrect ? Icons.check_circle : Icons.cancel,
                    color: isCorrect ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Text(
              questionText,
              style: TextStyle(
                fontSize: isMobile ? 15 : 17,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 20),
            ...['A', 'B', 'C', 'D'].map((option) {
              final optionText = options[option] ?? '';
              final isSelected = _selectedAnswers[questionId] == option;
              final showCorrect = isSubmitted && correctAnswer == option;
              final showWrong = isSubmitted && isSelected && !isCorrect;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: showCorrect
                      ? Colors.green[50]
                      : showWrong
                          ? Colors.red[50]
                          : isSelected
                              ? const Color(0xFFD62828).withOpacity(0.1)
                              : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: showCorrect
                        ? Colors.green
                        : showWrong
                            ? Colors.red
                            : isSelected
                                ? const Color(0xFFD62828)
                                : Colors.grey[300]!,
                    width: showCorrect || showWrong ? 2 : 1,
                  ),
                ),
                child: RadioListTile<String>(
                  title: Text(
                    '$option. $optionText',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: showCorrect || showWrong
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: showCorrect
                          ? Colors.green[900]
                          : showWrong
                              ? Colors.red[900]
                              : Colors.black87,
                    ),
                  ),
                  value: option,
                  groupValue: _selectedAnswers[questionId],
                  onChanged: isSubmitted
                      ? null
                      : (value) {
                          setState(() {
                            _selectedAnswers[questionId] = value!;
                          });
                        },
                  activeColor: const Color(0xFFD62828),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              );
            }),
            if (!isSubmitted && _selectedAnswers.containsKey(questionId)) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _submitAnswer(
                    questionId,
                    correctAnswer,
                    xpValue,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD62828),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 12 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Submit Answer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
            if (isSubmitted) ...[
              const SizedBox(height: 20),
              Container(
                padding: EdgeInsets.all(isMobile ? 14 : 16),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isCorrect ? Colors.green[300]! : Colors.red[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.error,
                          color: isCorrect ? Colors.green[700] : Colors.red[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCorrect ? 'Correct!' : 'Incorrect',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 15 : 16,
                            color: isCorrect ? Colors.green[900] : Colors.red[900],
                          ),
                        ),
                      ],
                    ),
                    if (explanation.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        explanation,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 15,
                          height: 1.5,
                          color: isCorrect ? Colors.green[900] : Colors.red[900],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  void _submitAnswer(String questionId, String correctAnswer, int xpValue) {
    final selectedAnswer = _selectedAnswers[questionId];
    if (selectedAnswer == null) return;
    
    final isCorrect = selectedAnswer == correctAnswer;
    
    setState(() {
      _submittedAnswers[questionId] = isCorrect;
    });
    
    // Note: Individual answer submission not implemented in science service
    // Progress is tracked via completeSection and submitQuiz methods
    
    if (isCorrect) {
      setState(() {
        totalXP += xpValue;
      });
    }
  }

  Widget _buildNavigationButtons(Color subjectColor) {
    final currentSections = sectionsMap[currentChapterId] ?? [];
    final hasPrevious = selectedSectionIndex > 0 || selectedChapterIndex > 0;
    final hasNext = selectedSectionIndex < currentSections.length - 1 || 
                   selectedChapterIndex < chapters.length - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (hasPrevious)
          OutlinedButton.icon(
            onPressed: _navigateToPreviousSection,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Previous'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFD62828),
              side: const BorderSide(color: Color(0xFFD62828)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          )
        else
          const SizedBox(),
        if (hasNext)
          ElevatedButton.icon(
            onPressed: _navigateToNextSection,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD62828),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          )
        else
          const SizedBox(),
      ],
    );
  }

  Widget _buildMobileBottomNav(Color subjectColor) {
    final currentSections = sectionsMap[currentChapterId] ?? [];
    final hasPrevious = selectedSectionIndex > 0 || selectedChapterIndex > 0;
    final hasNext = selectedSectionIndex < currentSections.length - 1 || 
                   selectedChapterIndex < chapters.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (hasPrevious)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _navigateToPreviousSection,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Prev'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFD62828),
                  side: const BorderSide(color: Color(0xFFD62828)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
          const SizedBox(width: 16),
          if (hasNext)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigateToNextSection,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD62828),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  double _calculateOverallProgress() {
    int totalSections = 0;
    for (final sections in sectionsMap.values) {
      totalSections += sections.length;
    }
    if (totalSections == 0) return 0;
    return completedSections.length / totalSections;
  }
}

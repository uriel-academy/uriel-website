import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epub_view/epub_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/storage_service.dart';

class EnhancedEpubReaderPage extends StatefulWidget {
  final String bookTitle;
  final String author;
  final String assetPath;
  final String bookId;

  const EnhancedEpubReaderPage({
    super.key,
    required this.bookTitle,
    required this.author,
    required this.assetPath,
    required this.bookId,
  });

  @override
  State<EnhancedEpubReaderPage> createState() => _EnhancedEpubReaderPageState();
}

class _EnhancedEpubReaderPageState extends State<EnhancedEpubReaderPage> with SingleTickerProviderStateMixin {
  late EpubController _epubController;
  bool _isLoading = true;
  String? _error;
  
  // UI State
  bool _showAppBar = true;
  bool _showBottomBar = true;
  bool _showSettings = false;
  bool _showTOC = false;
  late AnimationController _animationController;
  
  // TOC State
  bool _showBookmarksTab = false;
  
  // Reading Settings
  String _fontFamily = 'Merriweather'; // Serif for classics
  double _fontSize = 18.0;
  double _lineHeight = 1.6;
  double _marginHorizontal = 24.0;
  String _theme = 'cream'; // cream, white, sepia, dark, night
  String _alignment = 'justified';
  
  // Reading Progress
  int _currentPage = 0;
  double _progress = 0.0;
  int _totalPages = 0;
  DateTime? _sessionStartTime;
  Duration _totalReadingTime = Duration.zero;
  
  // Bookmarks & Highlights
  List<Map<String, dynamic>> _bookmarks = [];
  List<Map<String, dynamic>> _highlights = [];
  List<Map<String, dynamic>> _notes = [];
  
  // TTS
  FlutterTts? _flutterTts;
  bool _isReading = false;
  
  // Extracted book content
  EpubBook? _epubBook;
  List<String> _chapterTexts = [];
  // ignore: unused_field
  List<String> _chapterTitles = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initTts();
    _loadSettings();
    _loadEpub();
    _sessionStartTime = DateTime.now();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts?.setLanguage("en-US");
    await _flutterTts?.setSpeechRate(0.5);
    await _flutterTts?.setVolume(1.0);
    await _flutterTts?.setPitch(1.0);

    _flutterTts?.setCompletionHandler(() {
      setState(() => _isReading = false);
    });

    _flutterTts?.setCancelHandler(() {
      setState(() => _isReading = false);
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontFamily = prefs.getString('reader_font') ?? 'Merriweather';
      _fontSize = prefs.getDouble('reader_fontSize') ?? 18.0;
      _lineHeight = prefs.getDouble('reader_lineHeight') ?? 1.6;
      _marginHorizontal = prefs.getDouble('reader_margin') ?? 24.0;
      _theme = prefs.getString('reader_theme') ?? 'cream';
      _alignment = prefs.getString('reader_alignment') ?? 'justified';
      
      // Load bookmarks
      final bookmarksJson = prefs.getString('bookmarks_${widget.bookId}');
      if (bookmarksJson != null) {
        _bookmarks = List<Map<String, dynamic>>.from(jsonDecode(bookmarksJson));
      }
      
      // Load highlights
      _loadHighlights();
      
      // Load notes
      _loadNotes();
      
      // Load reading time
      final totalSeconds = prefs.getInt('reading_time_${widget.bookId}') ?? 0;
      _totalReadingTime = Duration(seconds: totalSeconds);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('reader_font', _fontFamily);
    await prefs.setDouble('reader_fontSize', _fontSize);
    await prefs.setDouble('reader_lineHeight', _lineHeight);
    await prefs.setDouble('reader_margin', _marginHorizontal);
    await prefs.setString('reader_theme', _theme);
    await prefs.setString('reader_alignment', _alignment);
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_position_${widget.bookId}', 
      jsonEncode({
        'page': _currentPage,
        'progress': _progress,
        'totalPages': _totalPages,
        'timestamp': DateTime.now().toIso8601String(),
      })
    );
  }

  Future<Map<String, dynamic>?> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPosJson = prefs.getString('last_position_${widget.bookId}');
    
    if (lastPosJson != null) {
      try {
        return jsonDecode(lastPosJson);
      } catch (e) {
        // Invalid progress data, ignore and return null
      }
    }
    return null;
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bookmarks_${widget.bookId}', jsonEncode(_bookmarks));
  }

  Future<void> _saveHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('highlights_${widget.bookId}', jsonEncode(_highlights));
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes_${widget.bookId}', jsonEncode(_notes));
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final notesJson = prefs.getString('notes_${widget.bookId}');
    if (notesJson != null) {
      _notes = List<Map<String, dynamic>>.from(jsonDecode(notesJson));
    }
  }

  Future<void> _loadHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final highlightsJson = prefs.getString('highlights_${widget.bookId}');
    if (highlightsJson != null) {
      _highlights = List<Map<String, dynamic>>.from(jsonDecode(highlightsJson));
    }
  }

  Future<Uint8List?> _loadFromAssets() async {
    try {
      final assetBytes = await rootBundle.load(widget.assetPath);
      return assetBytes.buffer.asUint8List();
    } catch (e) {
      debugPrint('Failed to load from assets: $e');
      return null;
    }
  }

  Future<void> _loadEpub() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      Uint8List? bytes;

      // Try to load from Firebase Storage first (for lazy loading)
      if (widget.assetPath.startsWith('storage://')) {
        // Extract filename from storage path
        final fileName = widget.assetPath.replaceFirst('storage://', '');
        bytes = await StorageService.downloadStorybook(fileName);
      }

      // Fallback to assets if storage fails or if it's an asset path
      bytes ??= await _loadFromAssets();

      // Final check if we have bytes
      if (bytes!.isEmpty) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load book content';
        });
        return;
      }
      
      // Load EPUB for text extraction
      _epubBook = await EpubReader.readBook(bytes);
      await _extractChapterTexts();
      
      // Load EPUB for viewing
      _epubController = EpubController(
        document: EpubDocument.openData(bytes),
      );

      // Load saved progress
      final savedProgress = await _loadProgress();
      if (savedProgress != null) {
        setState(() {
          _currentPage = savedProgress['page'] ?? 0;
          _progress = savedProgress['progress'] ?? 0.0;
          _totalPages = savedProgress['totalPages'] ?? 0;
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _saveReadingTime() async {
    if (_sessionStartTime != null) {
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      _totalReadingTime += sessionDuration;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('reading_time_${widget.bookId}', _totalReadingTime.inSeconds);
      _sessionStartTime = DateTime.now(); // Reset for next session
    }
  }

  Future<void> _extractChapterTexts() async {
    if (_epubBook == null) return;

    final chapters = <String>[];
    final titles = <String>[];

    // Extract text from chapters in reading order
    for (final chapter in _epubBook!.Chapters ?? []) {
      final title = chapter.Title ?? chapter.SubChapters?.firstOrNull?.Title ?? 'Chapter ${chapters.length + 1}';
      final text = _extractTextFromChapter(chapter);
      
      if (text.isNotEmpty) {
        titles.add(title);
        chapters.add(text);
      }
    }

    // If no chapters found, try to extract from the spine
    if (chapters.isEmpty && _epubBook!.Schema?.Package?.Spine?.Items != null) {
      for (final spineItem in _epubBook!.Schema!.Package!.Spine!.Items!) {
        final manifestItem = _epubBook!.Schema!.Package!.Manifest!.Items!
            .firstWhere((item) => item.Id == spineItem.IdRef);
        
        final content = _epubBook!.Content?.AllFiles?[manifestItem.Href];
        if (content != null) {
          String text = '';
          if (content is EpubTextContentFile) {
            text = content.Content ?? '';
          } else if (content is EpubByteContentFile) {
            // Try to decode as text
            try {
              text = String.fromCharCodes(content.Content ?? []);
            } catch (e) {
              // Skip binary files
              continue;
            }
          }
          
          text = _extractTextFromHtml(text);
          if (text.isNotEmpty) {
            titles.add('Chapter ${chapters.length + 1}');
            chapters.add(text);
          }
        }
      }
    }

    setState(() {
      _chapterTitles = titles;
      _chapterTexts = chapters;
    });
  }

  String _extractTextFromChapter(EpubChapter chapter) {
    // Extract text from the chapter content
    String text = '';
    
    if (chapter.HtmlContent != null) {
      text = _extractTextFromHtml(chapter.HtmlContent!);
    }
    
    // Also check subchapters
    if (chapter.SubChapters != null) {
      for (final subChapter in chapter.SubChapters!) {
        text += ' ${_extractTextFromChapter(subChapter)}';
      }
    }
    
    return text.trim();
  }

  String _extractTextFromHtml(String htmlContent) {
    // Simple HTML text extraction - remove tags and decode entities
    String text = htmlContent;
    
    // Remove HTML tags
    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
    
    // Decode common HTML entities
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    
    // Clean up whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return text;
  }

  void _toggleBars() {
    setState(() {
      _showAppBar = !_showAppBar;
      _showBottomBar = !_showBottomBar;
    });
    
    if (_showAppBar) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _addNote() {
    final TextEditingController noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Note', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: noteController,
          decoration: InputDecoration(
            hintText: 'Enter your note...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          ElevatedButton(
            onPressed: () {
              if (noteController.text.trim().isNotEmpty) {
                final note = {
                  'page': _currentPage,
                  'progress': _progress,
                  'text': noteController.text.trim(),
                  'timestamp': DateTime.now().toIso8601String(),
                };
                
                setState(() {
                  _notes.add(note);
                });
                
                _saveNotes();
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Note added', style: GoogleFonts.inter()),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getThemeColors()['accent'],
              foregroundColor: Colors.white,
            ),
            child: Text('Add Note', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }

  void _addBookmark() {
    final bookmark = {
      'page': _currentPage,
      'progress': _progress,
      'title': 'Page ${_currentPage + 1}',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _bookmarks.add(bookmark);
    });
    
    _saveBookmarks();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Bookmark added', style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addHighlight() {
    // For now, highlight the current page
    // Full text selection highlighting would require more complex EPUB integration
    final highlight = {
      'page': _currentPage,
      'progress': _progress,
      'text': 'Page ${_currentPage + 1} highlighted',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    setState(() {
      _highlights.add(highlight);
    });
    
    _saveHighlights();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Highlight added', style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareBook() {
    Share.share(
      'I\'m reading "${widget.bookTitle}" by ${widget.author} on Uriel Academy!\n\nhttps://uriel-academy-41fb0.web.app',
      subject: widget.bookTitle,
    );
  }

  Future<void> _toggleReadAloud() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_isReading) {
      await _flutterTts?.stop();
      setState(() => _isReading = false);
    } else {
      setState(() => _isReading = true);

      try {
        String textToRead = '';

        // Try to get current chapter text
        if (_chapterTexts.isNotEmpty) {
          // Estimate current chapter based on progress
          final currentChapterIndex = (_progress * _chapterTexts.length).toInt().clamp(0, _chapterTexts.length - 1);
          textToRead = _chapterTexts[currentChapterIndex];
        }

        // Fallback to sample text if no chapter text available
        if (textToRead.isEmpty) {
          textToRead = "Reading ${widget.bookTitle} by ${widget.author}. You are currently at page ${_currentPage + 1} of approximately $_totalPages pages, which is ${(_progress * 100).toStringAsFixed(0)} percent complete.";
        }

        // Chunk the text for better TTS performance
        final chunks = _chunkText(textToRead);

        // Speak each chunk
        for (final chunk in chunks) {
          if (!_isReading) break; // Stop if user cancelled
          await _flutterTts?.speak(chunk);
          await _waitForSpeechCompletion();
        }

        // Show feedback
        messenger.showSnackBar(
          SnackBar(
            content: Text('Reading aloud completed', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Text-to-speech not available', style: GoogleFonts.inter()),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() => _isReading = false);
      }
    }
  }

  List<String> _chunkText(String text, {int chunkSize = 1500}) {
    final chunks = <String>[];
    var start = 0;

    while (start < text.length) {
      var end = (start + chunkSize).clamp(0, text.length);

      // Try to break at sentence boundary
      final sentenceEnd = text.lastIndexOf(RegExp(r'[.!?]\s'), end);
      if (sentenceEnd > start + 200) {
        end = sentenceEnd + 1;
      }

      final chunk = text.substring(start, end).trim();
      if (chunk.isNotEmpty) {
        chunks.add(chunk);
      }

      start = end;
    }

    return chunks.where((chunk) => chunk.isNotEmpty).toList();
  }

  Future<void> _waitForSpeechCompletion() async {
    while (_isReading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Map<String, Color> _getThemeColors() {
    switch (_theme) {
      case 'white':
        return {
          'bg': Colors.white,
          'text': const Color(0xFF1A1A1A),
          'secondary': const Color(0xFF666666),
          'accent': const Color(0xFFD62828),
        };
      case 'cream':
        return {
          'bg': const Color(0xFFFFFDF5),
          'text': const Color(0xFF2C2416),
          'secondary': const Color(0xFF6B5D48),
          'accent': const Color(0xFFD62828),
        };
      case 'sepia':
        return {
          'bg': const Color(0xFFF4ECD8),
          'text': const Color(0xFF3D3427),
          'secondary': const Color(0xFF5C4A3C),
          'accent': const Color(0xFFB8860B),
        };
      case 'dark':
        return {
          'bg': const Color(0xFF1E1E1E),
          'text': const Color(0xFFE0E0E0),
          'secondary': const Color(0xFFB0B0B0),
          'accent': const Color(0xFFFF6B6B),
        };
      case 'night':
        return {
          'bg': const Color(0xFF000000),
          'text': const Color(0xFFCCCCCC),
          'secondary': const Color(0xFF999999),
          'accent': const Color(0xFFFF6B6B),
        };
      default:
        return {
          'bg': const Color(0xFFFFFDF5),
          'text': const Color(0xFF2C2416),
          'secondary': const Color(0xFF6B5D48),
          'accent': const Color(0xFFD62828),
        };
    }
  }

  @override
  void dispose() {
    _saveReadingTime();
    _saveProgress();
    _flutterTts?.stop();
    _epubController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _getThemeColors();
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: theme['bg'],
      body: _isLoading
          ? _buildLoadingState(theme)
          : _error != null
              ? _buildErrorState(theme)
              : Stack(
                  children: [
                    // Main Reading Area
                    GestureDetector(
                      onTap: _toggleBars,
                      child: Container(
                        color: theme['bg'],
                        child: SafeArea(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : _marginHorizontal,
                            ),
                            child: EpubView(
                              controller: _epubController,
                              builders: EpubViewBuilders<DefaultBuilderOptions>(
                                options: DefaultBuilderOptions(
                                  textStyle: _getTextStyle(theme),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Top App Bar
                    if (_showAppBar) _buildTopBar(theme, isMobile),

                    // Bottom Navigation Bar
                    if (_showBottomBar) _buildBottomBar(theme, isMobile),

                    // Settings Panel
                    if (_showSettings) _buildSettingsPanel(theme, isMobile),

                    // Table of Contents
                    if (_showTOC) _buildTOCPanel(theme, isMobile),
                  ],
                ),
    );
  }

  TextStyle _getTextStyle(Map<String, Color> theme) {
    TextStyle baseStyle;
    
    switch (_fontFamily) {
      case 'Merriweather':
        baseStyle = GoogleFonts.merriweather();
        break;
      case 'Lora':
        baseStyle = GoogleFonts.lora();
        break;
      case 'Crimson Text':
        baseStyle = GoogleFonts.crimsonText();
        break;
      case 'Inter':
        baseStyle = GoogleFonts.inter();
        break;
      default:
        baseStyle = GoogleFonts.merriweather();
    }

    return baseStyle.copyWith(
      fontSize: _fontSize,
      height: _lineHeight,
      color: theme['text'],
      letterSpacing: 0.3,
    );
  }

  Widget _buildLoadingState(Map<String, Color> theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme['accent']!),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading ${widget.bookTitle}...',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: theme['secondary'],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Map<String, Color> theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme['accent']),
            const SizedBox(height: 24),
            Text(
              'Failed to load book',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme['text'],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme['secondary'],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadEpub,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme['accent'],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Retry', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Map<String, Color> theme, bool isMobile) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: _showAppBar ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: theme['bg']!.withValues(alpha: 0.95),
            border: Border(
              bottom: BorderSide(
                color: theme['text']!.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: 12,
              ),
              child: Row(
                children: [
                  // Back Button
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    color: theme['text'],
                    onPressed: () {
                      _saveReadingTime();
                      _saveProgress();
                      Navigator.pop(context);
                    },
                    tooltip: 'Back to Library',
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Book Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.bookTitle,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: theme['text'],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.author,
                          style: GoogleFonts.inter(
                            fontSize: isMobile ? 12 : 13,
                            color: theme['secondary'],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Action Buttons
                  if (!isMobile) ...[
                    IconButton(
                      icon: const Icon(Icons.bookmark_border, size: 22),
                      color: theme['text'],
                      onPressed: _addBookmark,
                      tooltip: 'Add Bookmark',
                    ),
                    IconButton(
                      icon: Icon(_isReading ? Icons.stop : Icons.volume_up, size: 22),
                      color: theme['text'],
                      onPressed: _toggleReadAloud,
                      tooltip: _isReading ? 'Stop Reading' : 'Read Aloud',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 22),
                      color: theme['text'],
                      onPressed: _shareBook,
                      tooltip: 'Share',
                    ),
                  ],
                  
                  IconButton(
                    icon: const Icon(Icons.tune, size: 22),
                    color: theme['text'],
                    onPressed: () => setState(() {
                      _showSettings = !_showSettings;
                      if (_showSettings) _showTOC = false;
                    }),
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Map<String, Color> theme, bool isMobile) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedSlide(
        offset: _showBottomBar ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          decoration: BoxDecoration(
            color: theme['bg']!.withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(
                color: theme['text']!.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(_progress * 100).toStringAsFixed(0)}% Complete',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme['secondary'],
                            ),
                          ),
                          Text(
                            _totalPages > 0 ? 'Chapter ${_currentPage + 1} of $_totalPages' : '',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme['secondary'],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTapDown: (details) => _seekToPosition(details, context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: _progress,
                            backgroundColor: theme['text']!.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(theme['accent']!),
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Navigation Controls
                Padding(
                  padding: EdgeInsets.only(
                    left: isMobile ? 12 : 20,
                    right: isMobile ? 12 : 20,
                    bottom: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (isMobile) ...[
                        _buildBottomButton(
                          icon: Icons.bookmark_border,
                          label: 'Mark',
                          theme: theme,
                          onTap: _addBookmark,
                        ),
                        _buildBottomButton(
                          icon: Icons.highlight,
                          label: 'Highlight',
                          theme: theme,
                          onTap: _addHighlight,
                        ),
                        _buildBottomButton(
                          icon: Icons.note_add,
                          label: 'Note',
                          theme: theme,
                          onTap: _addNote,
                        ),
                        _buildBottomButton(
                          icon: _isReading ? Icons.stop : Icons.volume_up,
                          label: _isReading ? 'Stop' : 'Audio',
                          theme: theme,
                          onTap: _toggleReadAloud,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButton({
    required IconData icon,
    required String label,
    required Map<String, Color> theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: theme['text']),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme['secondary'],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPanel(Map<String, Color> theme, bool isMobile) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: AnimatedSlide(
        offset: _showSettings ? Offset.zero : const Offset(1, 0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          width: isMobile ? MediaQuery.of(context).size.width * 0.85 : 400,
          decoration: BoxDecoration(
            color: theme['bg'],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reading Settings',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme['text'],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: theme['text'],
                        onPressed: () => setState(() => _showSettings = false),
                      ),
                    ],
                  ),
                ),
                
                Divider(color: theme['text']!.withValues(alpha: 0.1), height: 1),
                
                // Settings Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSettingSection(
                        'Font Family',
                        theme,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Merriweather', 'Lora', 'Crimson Text', 'Inter']
                              .map((font) => _buildChip(font, _fontFamily == font, theme, () {
                                    setState(() => _fontFamily = font);
                                    _saveSettings();
                                  }))
                              .toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      _buildSettingSection(
                        'Font Size',
                        theme,
                        child: Row(
                          children: [
                            Text('A', style: TextStyle(fontSize: 14, color: theme['secondary'])),
                            Expanded(
                              child: Slider(
                                value: _fontSize,
                                min: 12,
                                max: 28,
                                divisions: 16,
                                activeColor: theme['accent'],
                                inactiveColor: theme['text']!.withValues(alpha: 0.2),
                                onChanged: (value) {
                                  setState(() => _fontSize = value);
                                  _saveSettings();
                                },
                              ),
                            ),
                            Text('A', style: TextStyle(fontSize: 24, color: theme['secondary'])),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      _buildSettingSection(
                        'Line Spacing',
                        theme,
                        child: Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _lineHeight,
                                min: 1.2,
                                max: 2.4,
                                divisions: 12,
                                label: _lineHeight.toStringAsFixed(1),
                                activeColor: theme['accent'],
                                inactiveColor: theme['text']!.withValues(alpha: 0.2),
                                onChanged: (value) {
                                  setState(() => _lineHeight = value);
                                  _saveSettings();
                                },
                              ),
                            ),
                            Text(
                              _lineHeight.toStringAsFixed(1),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme['text'],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      _buildSettingSection(
                        'Color Theme',
                        theme,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildThemeChip('White', 'white', Colors.white, const Color(0xFF1A1A1A), theme),
                            _buildThemeChip('Cream', 'cream', const Color(0xFFFFFDF5), const Color(0xFF2C2416), theme),
                            _buildThemeChip('Sepia', 'sepia', const Color(0xFFF4ECD8), const Color(0xFF3D3427), theme),
                            _buildThemeChip('Dark', 'dark', const Color(0xFF1E1E1E), const Color(0xFFE0E0E0), theme),
                            _buildThemeChip('Night', 'night', const Color(0xFF000000), const Color(0xFFCCCCCC), theme),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      _buildSettingSection(
                        'Text Alignment',
                        theme,
                        child: Wrap(
                          spacing: 8,
                          children: ['Left', 'Justified']
                              .map((align) => _buildChip(
                                    align,
                                    _alignment == align.toLowerCase(),
                                    theme,
                                    () {
                                      setState(() => _alignment = align.toLowerCase());
                                      _saveSettings();
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Quick Actions
                      _buildSettingSection(
                        'Quick Actions',
                        theme,
                        child: Column(
                          children: [
                            _buildActionButton(
                              icon: Icons.menu_book,
                              label: 'Table of Contents',
                              theme: theme,
                              onTap: () {
                                setState(() {
                                  _showSettings = false;
                                  _showTOC = true;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildActionButton(
                              icon: Icons.share,
                              label: 'Share Book',
                              theme: theme,
                              onTap: () {
                                setState(() => _showSettings = false);
                                _shareBook();
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Reading Statistics
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme['accent']!.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reading Statistics',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme['text'],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Time',
                                  style: GoogleFonts.inter(fontSize: 13, color: theme['secondary']),
                                ),
                                Text(
                                  _formatReadingTime(_totalReadingTime),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme['text'],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Progress',
                                  style: GoogleFonts.inter(fontSize: 13, color: theme['secondary']),
                                ),
                                Text(
                                  '${(_progress * 100).toStringAsFixed(0)}%',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme['text'],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Notes',
                                  style: GoogleFonts.inter(fontSize: 13, color: theme['secondary']),
                                ),
                                Text(
                                  '${_notes.length}',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme['text'],
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTOCPanel(Map<String, Color> theme, bool isMobile) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: AnimatedSlide(
        offset: _showTOC ? Offset.zero : const Offset(-1, 0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          width: isMobile ? MediaQuery.of(context).size.width * 0.85 : 350,
          decoration: BoxDecoration(
            color: theme['bg'],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Table of Contents',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme['text'],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: theme['text'],
                        onPressed: () => setState(() => _showTOC = false),
                      ),
                    ],
                  ),
                ),
                
                Divider(color: theme['text']!.withValues(alpha: 0.1), height: 1),
                
                // Bookmarks Tab
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme['text']!.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _showBookmarksTab = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !_showBookmarksTab ? theme['accent'] : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Chapters',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: !_showBookmarksTab ? Colors.white : theme['secondary'],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _showBookmarksTab = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _showBookmarksTab ? theme['accent'] : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Bookmarks',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _showBookmarksTab ? Colors.white : theme['secondary'],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // TOC Content
                Expanded(
                  child: _showBookmarksTab ? _buildBookmarksList(theme) : _buildChaptersList(theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingSection(String title, Map<String, Color> theme, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme['secondary'],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Map<String, Color> theme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme['text']!.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme['text']!.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme['text']),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme['text'],
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: theme['secondary']),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, Map<String, Color> theme, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? theme['accent'] : theme['text']!.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme['accent']! : theme['text']!.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : theme['text'],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeChip(String label, String value, Color bg, Color text, Map<String, Color> currentTheme) {
    final isSelected = _theme == value;
    
    return InkWell(
      onTap: () {
        setState(() => _theme = value);
        _saveSettings();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? currentTheme['accent']! : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: text,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarksList(Map<String, Color> theme) {
    if (_bookmarks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.bookmark_border, size: 48, color: theme['secondary']),
          const SizedBox(height: 16),
          Text(
            'No bookmarks yet',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme['text'],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the bookmark icon while reading to save your place.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme['secondary'],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        return InkWell(
          onTap: () {
            // Navigate to bookmark position
            final progress = bookmark['progress'] ?? 0.0;
            _jumpToProgress(progress);
            setState(() => _showTOC = false);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme['text']!.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme['text']!.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.bookmark, size: 20, color: theme['accent']),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookmark['title'] ?? 'Bookmark',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme['text'],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Page ${(bookmark['page'] ?? 0) + 1} • ${((bookmark['progress'] ?? 0.0) * 100).toStringAsFixed(0)}% complete',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme['secondary'],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: theme['secondary']),
                  onPressed: () {
                    setState(() {
                      _bookmarks.removeAt(index);
                    });
                    _saveBookmarks();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChaptersList(Map<String, Color> theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 20),
        Text(
          'Table of Contents',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme['text'],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Chapter navigation will be available once EPUB chapter data is extracted from the book file.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: theme['secondary'],
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme['accent']!.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.menu_book, size: 32, color: theme['accent']),
              const SizedBox(height: 12),
              Text(
                'Coming Soon',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme['text'],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _seekToPosition(TapDownDetails details, BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final localPosition = box.globalToLocal(details.globalPosition);
    final progressBarWidth = box.size.width - 40; // Account for padding
    final tapX = localPosition.dx - 20; // Account for left padding
    
    if (tapX >= 0 && tapX <= progressBarWidth) {
      final newProgress = tapX / progressBarWidth;
      _jumpToProgress(newProgress);
    }
  }

  Future<void> _jumpToProgress(double progress) async {
    // For now, just update the progress visually
    // Full navigation would require more complex EPUB API integration
    setState(() {
      _progress = progress;
      _currentPage = (_progress * _totalPages).toInt();
    });
    _saveProgress();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigation to ${(progress * 100).toInt()}% coming soon', 
          style: GoogleFonts.inter()),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatReadingTime(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }
}

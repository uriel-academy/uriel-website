import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:epub_view/epub_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';

class EpubReaderPage extends StatefulWidget {
  final String bookTitle;
  final String author;
  final String assetPath;
  final String bookId;

  const EpubReaderPage({
    super.key,
    required this.bookTitle,
    required this.author,
    required this.assetPath,
    required this.bookId,
  });

  @override
  State<EpubReaderPage> createState() => _EpubReaderPageState();
}

class _EpubReaderPageState extends State<EpubReaderPage> {
  late EpubController _epubController;
  bool _isLoading = true;
  String? _error;
  bool _showSettings = false;
  
  // Settings
  double _fontSize = 18.0;
  Color _backgroundColor = Colors.white;
  Color _textColor = Colors.black;
  
  // Text-to-Speech
  FlutterTts? _flutterTts;
  bool _isReading = false;
  String? _selectedText;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadEpub();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts?.setLanguage("en-US");
    await _flutterTts?.setSpeechRate(0.5);
    await _flutterTts?.setVolume(1.0);
    await _flutterTts?.setPitch(1.0);

    _flutterTts?.setCompletionHandler(() {
      setState(() {
        _isReading = false;
      });
    });
  }

  Future<void> _loadEpub() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load EPUB from assets
      final bytes = await rootBundle.load(widget.assetPath);
      
      _epubController = EpubController(
        document: EpubDocument.openData(bytes.buffer.asUint8List()),
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load book: ${e.toString()}';
      });
      debugPrint('Error loading EPUB: $e');
    }
  }

  Future<void> _toggleReadAloud() async {
    if (_isReading) {
      await _flutterTts?.stop();
      setState(() {
        _isReading = false;
      });
    } else {
      // Get current page text if available
      // Note: EPUB view doesn't expose text directly, so this is a placeholder
      // In a production app, you'd need to extract text from the current chapter
      setState(() {
        _isReading = true;
      });
      // This would need proper implementation with chapter text extraction
      await _flutterTts?.speak("Reading functionality requires chapter text extraction. This is a demo.");
    }
  }

  void _shareQuote() {
    if (_selectedText != null && _selectedText!.isNotEmpty) {
      final quote = '"$_selectedText"\n\n— From "${widget.bookTitle}" by ${widget.author}';
      Share.share(quote, subject: 'Quote from ${widget.bookTitle}');
    } else {
      // Share book info if no text selected
      Share.share(
        'I\'m reading "${widget.bookTitle}" by ${widget.author} on Uriel Academy!',
        subject: widget.bookTitle,
      );
    }
  }

  @override
  void dispose() {
    _flutterTts?.stop();
    _epubController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1E3F),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bookTitle,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'by ${widget.author}',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareQuote,
            tooltip: 'Share Quote',
          ),
          // Read Aloud button
          IconButton(
            icon: Icon(_isReading ? Icons.stop : Icons.volume_up),
            onPressed: _toggleReadAloud,
            tooltip: _isReading ? 'Stop Reading' : 'Read Aloud',
          ),
          // Settings button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => setState(() => _showSettings = !_showSettings),
            tooltip: 'Reading Settings',
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _error != null
              ? _buildErrorState()
              : Stack(
                  children: [
                    // EPUB Reader
                    Container(
                      color: _backgroundColor,
                      child: EpubView(
                        controller: _epubController,
                        builders: EpubViewBuilders<DefaultBuilderOptions>(
                          options: DefaultBuilderOptions(
                            textStyle: TextStyle(
                              fontSize: _fontSize,
                              color: _textColor,
                              height: 1.6,
                            ),
                            paragraphPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          chapterDividerBuilder: (_) => Divider(
                            height: 32,
                            color: _textColor.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                    ),

                    // Settings Panel
                    if (_showSettings) _buildSettingsPanel(),
                  ],
                ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD62828)),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading "${widget.bookTitle}"...',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a moment',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Failed to Load Book',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error occurred',
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                _loadEpub();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD62828),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width > 768 ? 350 : MediaQuery.of(context).size.width * 0.85,
      child: Material(
        elevation: 8,
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1E3F),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Reading Settings',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _showSettings = false),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Font Size
                      Text(
                        'Font Size',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'A',
                            style: GoogleFonts.montserrat(fontSize: 14),
                          ),
                          Expanded(
                            child: Slider(
                              value: _fontSize,
                              min: 12,
                              max: 28,
                              divisions: 16,
                              label: _fontSize.round().toString(),
                              activeColor: const Color(0xFFD62828),
                              onChanged: (value) {
                                setState(() => _fontSize = value);
                              },
                            ),
                          ),
                          Text(
                            'A',
                            style: GoogleFonts.montserrat(fontSize: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Theme
                      Text(
                        'Reading Theme',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildThemeButton('Light', Colors.white, Colors.black),
                          _buildThemeButton('Sepia', const Color(0xFFF4ECD8), const Color(0xFF5C4A3C)),
                          _buildThemeButton('Dark', const Color(0xFF1A1A1A), Colors.white),
                          _buildThemeButton('Night', Colors.black, const Color(0xFFB0B0B0)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeButton(String name, Color bg, Color text) {
    final isSelected = _backgroundColor == bg && _textColor == text;
    
    return InkWell(
      onTap: () {
        setState(() {
          _backgroundColor = bg;
          _textColor = text;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(
            color: isSelected ? const Color(0xFFD62828) : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name,
          style: GoogleFonts.montserrat(
            color: text,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
// Note: UriAI and FirebaseAuth were previously used by the older inline _send implementation.
// The chat input has been moved to `UriChatInput` which handles sending. Keep imports removed to avoid unused warnings.
import 'uri_chat_input.dart';
import 'latex_markdown_builder.dart';

// Color constants matching design spec
class UrielColors {
  static const deepNavy = Color(0xFF1A1E3F);
  static const urielRed = Color(0xFFD62828);
  static const warmWhite = Color(0xFFFFF8F0);
  static const softGray = Color(0xFFF0F0F0);
  static const accentGreen = Color(0xFF2ECC71);
}

class UriChat extends StatefulWidget {
  final String? userName;
  final String? currentSubject;
  const UriChat({Key? key, this.userName, this.currentSubject}) : super(key: key);

  @override
  UriChatState createState() => UriChatState();
}

class UriChatState extends State<UriChat> with SingleTickerProviderStateMixin {
  bool _open = false;
  // messages: each message is a map: {role, text, id?, loading?}
  final _messages = <Map<String, dynamic>>[];
  bool _loading = false;
  bool _streamComplete = false;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  final FlutterTts _tts = FlutterTts();
  final ScrollController _scrollController = ScrollController();
  // messages will always render with KaTeX/Markdown

  // Suggestion chips
  // Suggestion chips removed per request

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _bounceController.forward();
  }

  @override
  void dispose() {
    _tts.stop();
    _bounceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Scroll to bottom of chat when new messages are added
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Expose a method so parent can open/close programmatically
  void setOpen(bool open) {
    if (!mounted) return;
    setState(() {
      _open = open;
    });
  }

  void _toggle() {
    setState(() => _open = !_open);
  }

  void _showMobileChatSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: UrielColors.warmWhite,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: UrielColors.warmWhite,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: UrielColors.urielRed,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Ask Uri...',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: UrielColors.deepNavy,
                                    ),
                                  ),
                                ),
                                // Always render KaTeX/Markdown — no toggle
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: UrielColors.deepNavy, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: UrielColors.softGray),
                    // Messages area
                    Expanded(
                      child: _messages.isEmpty && !_loading
                          ? _buildWelcomeMessage()
                          : _buildMessagesList(MediaQuery.of(context).size.width),
                    ),
                    // Input area with keyboard handling
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: _buildInputArea(),
                    ),
                    // Powered by footer
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Text(
                        'Powered by Uriel AI',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Clear messages when sheet is closed
      setState(() {
        _messages.clear();
        _loading = false;
      });
    });
  }

  // Facts API integration removed from the inline chat widget. The modular UriChatInput and server-side aiChat handle facts and persona.

  // _send() removed - input now uses UriChatInput and routes messages via onMessage
  // Removed legacy helpers used by previous inline _send implementation. The current input widget handles sending and message mode.

  // Text-to-speech helper removed (unused). Keep FlutterTts instance for future use.

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final buttonSize = isMobile ? 56.0 : 64.0;

    if (isMobile) {
      // Mobile: FAB button at bottom-right that opens modal bottom sheet
      return Positioned(
        right: 16,
        bottom: 80, // Above bottom navigation
        child: AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _bounceAnimation.value,
              child: child,
            );
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showMobileChatSheet(context),
              borderRadius: BorderRadius.circular(buttonSize / 2),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  color: UrielColors.urielRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // Desktop: Position at bottom-right corner
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 250),
        right: 20,
        bottom: 20,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_open) _buildDesktopSheet(context),
              AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _bounceAnimation.value,
                    child: child,
                  );
                },
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggle,
                    borderRadius: BorderRadius.circular(buttonSize / 2),
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: UrielColors.urielRed,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDesktopSheet(BuildContext context) {
    const width = 420.0;
    const height = 600.0; // Will be constrained by 70% viewport

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween(begin: 0.95, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.bottomRight,
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Material(
        elevation: 0,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          height: height,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: UrielColors.warmWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: UrielColors.softGray, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: UrielColors.warmWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: UrielColors.urielRed,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ask Uri...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: UrielColors.deepNavy,
                              ),
                            ),
                          ),
                          // Always render KaTeX/Markdown — no toggle
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: UrielColors.deepNavy, size: 20),
                      onPressed: () {
                        setState(() {
                          _open = false;
                          _messages.clear();
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: UrielColors.softGray),
              // Messages area
              Expanded(
                child: _messages.isEmpty && !_loading
                    ? _buildWelcomeMessage()
                    : _buildMessagesList(width),
              ),
              // Input area
              _buildInputArea(),
              // Powered by footer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  'Powered by Uriel AI',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeMessage() {
    // Welcome message and suggestion chips removed per request.
    // Return an empty widget so the messages area remains blank when there are no messages.
    return const SizedBox.shrink();
  }

  // Suggestion chips removed — helper intentionally omitted.


  Widget _buildMessagesList(double width) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (_loading && i == _messages.length) {
          return _buildTypingIndicator();
        }
        if (i >= _messages.length) {
          return const SizedBox.shrink();
        }
        final m = _messages[i];
        final isUser = m['role'] == 'user';
        // Cap bubble width to max 620px while keeping responsive behavior
        final cap = math.min(width * 0.8, 620.0);
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
              constraints: BoxConstraints(maxWidth: cap),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? UrielColors.urielRed.withValues(alpha: 0.1) // Light red tint for user
                    : Colors.white, // White background for bot
                border: Border.all(
                  color: UrielColors.softGray,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Smooth size changes when the streamed text updates
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    child: _buildMessageWithAttachments(m, isUser),
                  ),
                  // If not user and stream just finished and this is the newest message, show complete
                  if (!isUser && _streamComplete && i == _messages.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text('\u2713 complete', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ),
                ],
              ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    // Use the modular UriChatInput widget which handles image picking/upload
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: UrielColors.warmWhite,
        border: Border(top: BorderSide(color: UrielColors.softGray, width: 1)),
      ),
      child: UriChatInput(
        history: _messages
            .where((m) => !(m['role'] == 'assistant' && _loading)) // Exclude streaming assistant messages
            .map((m) => {'role': m['role'] as String? ?? 'user', 'content': m['text'] as String? ?? ''})
            .toList(),
        onMessage: (role, content, {attachments}) {
          setState(() {
            // Append messages in chronological order (newest at bottom)
            if (role == 'assistant') {
              // If last message is an assistant bubble, update its text (stream update)
              if (_messages.isNotEmpty && _messages.last['role'] == 'assistant') {
                _messages.last['text'] = content;
              } else {
                _messages.add({'role': role, 'text': content, 'id': '${role}_${DateTime.now().millisecondsSinceEpoch}', 'attachments': attachments});
              }
            } else {
              // User messages also go at the end
              _messages.add({'role': role, 'text': content, 'id': '${role}_${DateTime.now().millisecondsSinceEpoch}', 'attachments': attachments});
            }
          });
          _scrollToBottom();
        },
        onStreamStart: (cancelHandle) {
          setState(() {
            _loading = true; // show typing indicator
            _streamComplete = false;
          });
        },
        onStreamEnd: () {
          setState(() {
            _loading = false;
            _streamComplete = true;
          });
        },
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: UrielColors.softGray, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Uri is typing',
              style: TextStyle(
                color: UrielColors.deepNavy,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _bounceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: (index * 0.3 + _bounceController.value) % 1.0,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Render message text as Markdown with KaTeX support.
  // We look for inline $...$ and block $$...$$ math and render using MathRenderer (MathJax on web, flutter_math_fork on mobile).
  String normalizeLatex(String s) {
    // First apply comprehensive text normalization
    s = _normalizeMd(s);

    // Then normalize LaTeX delimiters
    return s
        .replaceAll(r'\\[', r'$$')
        .replaceAll(r'\\]', r'$$')
        .replaceAll(r'\\(', r'$')
        .replaceAll(r'\\)', r'$')
        .replaceAll(r'\[', r'$$')
        .replaceAll(r'\]', r'$$')
        .replaceAll(r'\(', r'$')
        .replaceAll(r'\)', r'$');
  }

  String _normalizeMd(String s) {
    debugPrint('=== NORMALIZING TEXT IN URI CHAT ===');
    debugPrint('Input: "${s.substring(0, math.min(300, s.length))}"');

    // Most critical fixes first - handle the exact patterns from AI output
    s = s.replaceAll(r'$1 .', '1.');
    s = s.replaceAll(r'$2 .', '2.');
    s = s.replaceAll(r'$3 .', '3.');
    s = s.replaceAll(r'$1', '1.');
    s = s.replaceAll(r'$2', '2.');
    s = s.replaceAll(r'$3', '3.');

    // Handle LaTeX markers - try multiple variations
    s = s.replaceAll('latex :', r'$');
    s = s.replaceAll('latex:', r'$');
    s = s.replaceAll(r'$$', r'$$');

    // Fix the specific pattern: "1**Text**:" -> "1. **Text**:"
    s = s.replaceAllMapped(RegExp(r'(\d+)\*\*([^*]+)\*\*:'), (match) => '${match.group(1)}. **${match.group(2)}**::');

    // Fix spacing issues that appear in the output
    s = s.replaceAll('in to', 'into');
    s = s.replaceAll('understand ing', 'understanding');
    s = s.replaceAll('discover ing', 'discovering');
    s = s.replaceAll('develop ing', 'developing');
    s = s.replaceAll('act up on', 'act upon');

    // Handle any remaining $ followed by digit patterns
    s = s.replaceAllMapped(RegExp(r'\$([0-9]+)'), (match) => '${match.group(1)}.');

    debugPrint('After critical fixes: "${s.substring(0, math.min(300, s.length))}"');

    // Continue with other normalization...
    // Fix common spacing issues that the AI creates
    // Remove spaces within words that shouldn't have them
    s = s.replaceAll('do ing', 'doing');
    s = s.replaceAll('origin al', 'original');
    s = s.replaceAll('theoret ical', 'theoretical');
    s = s.replaceAll('pract ical', 'practical');
    s = s.replaceAll('organ isms', 'organisms');
    s = s.replaceAll('fundament al', 'fundamental');
    s = s.replaceAll('conserv ation', 'conservation');
    s = s.replaceAll('particul ar', 'particular');
    s = s.replaceAll('express ions', 'expressions');
    s = s.replaceAll('polynom ial', 'polynomial');
    s = s.replaceAll('integr ation', 'integration');

    // Insert spaces between words that are run together using multiple strategies

    // Strategy 1: lowercase letter followed by uppercase letter (word boundary)
    s = s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}');

    // Strategy 2: Insert spaces based on common word patterns
    // Common word endings followed by common word beginnings
    final wordEndings = ['the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from', 'up', 'about', 'into', 'through', 'during', 'before', 'after', 'above', 'below', 'between', 'among', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'must', 'can', 'shall', 'city', 'capital', 'country', 'region', 'state', 'province', 'district', 'town', 'village'];
    final wordBeginnings = ['the', 'a', 'an', 'this', 'that', 'these', 'those', 'my', 'your', 'his', 'her', 'its', 'our', 'their', 'what', 'where', 'when', 'why', 'how', 'who', 'which', 'there', 'here', 'then', 'than', 'so', 'because', 'although', 'since', 'while', 'if', 'unless', 'until', 'before', 'after', 'as', 'like', 'unlike', 'capital', 'city', 'country', 'region', 'state', 'province', 'district', 'town', 'village', 'of', 'in', 'on', 'at', 'to', 'for', 'with', 'by', 'from'];

    for (final ending in wordEndings) {
      for (final beginning in wordBeginnings) {
        final pattern = '$ending$beginning';
        final replacement = '$ending $beginning';
        s = s.replaceAll(pattern, replacement);
      }
    }

    // Strategy 3: Handle numbers and letters
    s = s.replaceAllMapped(RegExp(r'([a-zA-Z])([0-9])'), (match) => '${match.group(1)} ${match.group(2)}');
    s = s.replaceAllMapped(RegExp(r'([0-9])([a-zA-Z])'), (match) => '${match.group(1)} ${match.group(2)}');

    // Strategy 4: Handle contractions and possessives
    s = s.replaceAllMapped(RegExp(r"([a-z])'([st]|re|ve|ll|m|d)([a-zA-Z])", caseSensitive: false), (match) => "${match.group(1)}'${match.group(2)} ${match.group(3)}");

    // Handle common abbreviations and ensure proper spacing
    s = s.replaceAll('e.g.', 'e.g.');
    s = s.replaceAll('i.e.', 'i.e.');
    s = s.replaceAll('etc.', 'etc.');
    s = s.replaceAll('Dr.', 'Dr.');
    s = s.replaceAll('Mr.', 'Mr.');
    s = s.replaceAll('Mrs.', 'Mrs.');
    s = s.replaceAll('Ms.', 'Ms.');

    // Collapse runs of whitespace
    s = s.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');

    // Remove space *before* punctuation , . ; : ? ! % ) ]
    s = s.replaceAll(RegExp(r'\s+([,.;:?!%])'), r'$1');
    s = s.replaceAll(RegExp(r'\s+([\)\]\}])'), r'$1');

    // Remove space *after* opening punctuation ( ( [ {
    s = s.replaceAll(RegExp(r'([\(\[\{])\s+'), r'$1');

    // Hyphenated compounds: evidence -based  -> evidence-based
    s = s.replaceAll(RegExp(r'(?<=[A-Za-z])\s*-\s*(?=[A-Za-z])'), '-');

    // Ensure a space after sentence-ending punctuation if followed by a letter/number
    s = s.replaceAll(RegExp(r'([.!?])([A-Za-z0-9])'), r'$1 $2');

    // Force numbered lists onto new lines: "... points: 1. ..." -> "\n1. ..."
    s = s.replaceAll(RegExp(r'(?<!^)\s+(\d+)\.\s'), '\n\$1. ');

    // Bullet lists sometimes arrive like "- item" but stuck to previous text
    s = s.replaceAll(RegExp(r'(?<!^)\s+(-\s+)'), '\n\$1');

    // Handle LaTeX expressions - ensure they're properly formatted
    s = s.replaceAll(r'$', r'$');
    s = s.replaceAll(r'$$', r'$$');

    debugPrint('Final normalized: "${s.substring(0, math.min(300, s.length))}"');
    return s.trim();
  }

  Widget _buildRenderedMessage(String text, bool isUser) {
    // Normalize LaTeX delimiters first
    final normalizedText = normalizeLatex(text);

    if (isUser) {
      return LatexMarkdown(
        data: normalizedText,
        textStyle: const TextStyle(fontSize: 15, height: 1.5),
        selectable: true,
      );
    }

    // For AI responses, use LatexMarkdown with navy color
    return LatexMarkdown(
      data: normalizedText,
      textStyle: const TextStyle(
        color: UrielColors.deepNavy,
        fontSize: 15,
        height: 1.5,
      ),
      selectable: true,
    );
  }

  Widget _buildMessageWithAttachments(Map<String, dynamic> m, bool isUser) {
    final contentWidget = _buildRenderedMessage(m['text'] ?? '', isUser);
    final attachments = (m['attachments'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if ((m['text'] ?? '').toString().trim().isNotEmpty) contentWidget,
        for (final a in attachments)
          if ((a['type'] ?? '') == 'image')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onTap: () => showDialog(context: context, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(a['url'] ?? '')))),
                  child: Image.network(a['url'] ?? '', height: 160, fit: BoxFit.cover),
                ),
              ),
            ),
      ],
    );
  }
}

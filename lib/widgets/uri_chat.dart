import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_math_fork/flutter_math.dart';
// Note: UriAI and FirebaseAuth were previously used by the older inline _send implementation.
// The chat input has been moved to `UriChatInput` which handles sending. Keep imports removed to avoid unused warnings.
import 'uri_chat_input.dart';

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
          0.0, // Since reverse: true, position 0 is the bottom
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
                      color: Colors.black.withOpacity(0.3),
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
                            color: Colors.black.withOpacity(0.3),
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
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (_loading && i == 0) {
          return _buildTypingIndicator();
        }
        final messageIndex = i - (_loading ? 1 : 0);
        if (messageIndex < 0 || messageIndex >= _messages.length) {
          return const SizedBox.shrink(); // Safety check for invalid indices
        }
        final m = _messages[_messages.length - 1 - messageIndex];
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
                  if (!isUser && _streamComplete && messageIndex == _messages.length - 1)
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
        history: _messages.map((m) => {'role': m['role'] as String? ?? 'user', 'content': m['text'] as String? ?? ''}).toList(),
        onMessage: (role, content, {attachments}) {
          setState(() {
            // We keep the list in newest-first order so with reverse: true the
            // latest message appears at the bottom of the viewport. Insert at
            // index 0 for new messages and update index 0 for streaming updates.
            if (role == 'assistant') {
              // If first message is an assistant bubble, replace its text (stream update)
              if (_messages.isNotEmpty && _messages.first['role'] == 'assistant') {
                _messages[0]['text'] = content;
              } else {
                _messages.insert(0, {'role': role, 'text': content, 'id': '${role}_${DateTime.now().millisecondsSinceEpoch}', 'attachments': attachments});
              }
            } else {
              // user messages also go at the front (newest-first)
              _messages.insert(0, {'role': role, 'text': content, 'id': '${role}_${DateTime.now().millisecondsSinceEpoch}', 'attachments': attachments});
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
  // We look for inline $...$ and block $$...$$ math and render using flutter_math_fork.
  String normalizeLatex(String s) {
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

  Widget _buildRenderedMessage(String text, bool isUser) {
    if (isUser) return Text(text, style: const TextStyle(fontSize: 15, height: 1.5));

  final normalized = normalizeLatex(text);

    // helper to parse inline $...$
    List<InlineSpan> parseInline(String segment) {
      final spans = <InlineSpan>[];
      final reg = RegExp(r'\$(?!\$)(.+?)\$');
      var last = 0;
      for (final m in reg.allMatches(segment)) {
        if (m.start > last) spans.add(TextSpan(text: segment.substring(last, m.start)));
        final expr = m.group(1) ?? '';
        spans.add(WidgetSpan(child: Math.tex(expr, textStyle: const TextStyle(fontSize: 14))));
        last = m.end;
      }
      if (last < segment.length) spans.add(TextSpan(text: segment.substring(last)));
      return spans;
    }

    final blockReg = RegExp(r'\$\$(.+?)\$\$', dotAll: true);
    var lastBlock = 0;
    final children = <InlineSpan>[];
    for (final m in blockReg.allMatches(normalized)) {
      if (m.start > lastBlock) {
        final before = normalized.substring(lastBlock, m.start);
        children.addAll(parseInline(before));
      }
      final expr = m.group(1) ?? '';
      children.add(WidgetSpan(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Math.tex(expr, textStyle: const TextStyle(fontSize: 16)),
      )));
      lastBlock = m.end;
    }
    if (lastBlock < normalized.length) {
      final tail = normalized.substring(lastBlock);
      children.addAll(parseInline(tail));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: UrielColors.deepNavy, fontSize: 15, height: 1.5),
        children: children,
      ),
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

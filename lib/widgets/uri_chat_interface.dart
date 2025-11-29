import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'uri_chat_input.dart';

/// UriChatInterface provides the chat UI for interacting with Uri AI assistant.
/// 
/// Features:
/// - LaTeX/math rendering using flutter_math_fork
/// - Message history with user/assistant bubbles
/// - Typing indicator animation
/// - Image attachment support with fullscreen preview
/// - Responsive layout (mobile/desktop)
class UriChatInterface extends StatefulWidget {
  final String? userName;
  final String? currentSubject;

  const UriChatInterface({
    super.key,
    this.userName,
    this.currentSubject,
  });

  @override
  State<UriChatInterface> createState() => _UriChatInterfaceState();
}

class _UriChatInterfaceState extends State<UriChatInterface> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _fadeController.repeat(reverse: true);

    _initializeChat();
  }

  void _initializeChat() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addWelcomeMessage();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    final greeting = widget.userName != null
        ? 'Hi ${widget.userName}! 👋'
        : 'Hi there! 👋';

    final subjectContext = widget.currentSubject != null
        ? '\n\nI see you\'re studying ${widget.currentSubject}. I\'m here to help with any questions you have about this subject or anything else you\'re learning!'
        : '\n\nI\'m Uri, your AI study companion. I\'m here to help you with any questions about your studies. Feel free to ask me anything!';

    setState(() {
      _messages.insert(0, {
        'role': 'assistant',
        'content': '$greeting$subjectContext',
        'timestamp': DateTime.now(),
        'id': 'assistant_${_uuid.v4()}',
      });
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Normalizes LaTeX expressions for flutter_math_fork.
  /// Handles block math ($$...$$), inline math ($...$), and preserves text.
  String normalizeLatex(String text) {
    return text
        .replaceAll(r'\[', r'$$')
        .replaceAll(r'\]', r'$$')
        .replaceAll(r'\(', r'$')
        .replaceAll(r'\)', r'$')
        .replaceAll(r'\\', r'\')
        .replaceAll('\\n', '\n')
        .trim();
  }

  /// Parses inline content (text + inline math) into TextSpan children.
  List<InlineSpan> parseInline(String segment) {
    final children = <InlineSpan>[];
    final inlinePattern = RegExp(r'\$(.*?)\$');
    var lastEnd = 0;

    for (final match in inlinePattern.allMatches(segment)) {
      // Add text before the inline math
      if (match.start > lastEnd) {
        final preText = segment.substring(lastEnd, match.start);
        children.add(TextSpan(text: preText));
      }
      // Add inline math
      final expr = match.group(1)!;
      children.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Math.tex(expr, textStyle: const TextStyle(fontSize: 16)),
      ));
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < segment.length) {
      children.add(TextSpan(text: segment.substring(lastEnd)));
    }

    return children;
  }

  /// Builds a rendered message with LaTeX support.
  /// Handles block math ($$...$$) and inline math ($...$).
  Widget _buildRenderedMessage(String rawText, bool isUser) {
    final normalized = normalizeLatex(rawText);
    final children = <InlineSpan>[];

    // Match block math first
    final blockPattern = RegExp(r'\$\$(.*?)\$\$', dotAll: true);
    var lastBlock = 0;

    for (final m in blockPattern.allMatches(normalized)) {
      // Before block: parse inline content
      if (m.start > lastBlock) {
        final before = normalized.substring(lastBlock, m.start);
        children.addAll(parseInline(before));
      }
      // Block math
      final expr = m.group(1)!;
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
        style: TextStyle(
          color: isUser ? Colors.white : const Color(0xFF1A1E3F),
          fontSize: 15,
          height: 1.5,
        ),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Messages area
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFE),
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 24,
                  16,
                  isMobile ? 16 : 24,
                  keyboardHeight > 0 ? 16 : 80,
                ),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isLoading && index == _messages.length) {
                    return _buildTypingIndicator();
                  }

                  final message = _messages[_messages.length - 1 - index];
                  final isUser = message['role'] == 'user';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: isMobile ? MediaQuery.of(context).size.width * 0.8 : 600,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? const Color(0xFFD62828)
                                  : Colors.white,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(isUser ? 18 : 4),
                                topRight: Radius.circular(isUser ? 4 : 18),
                                bottomLeft: const Radius.circular(18),
                                bottomRight: const Radius.circular(18),
                              ),
                              border: !isUser ? Border.all(
                                color: const Color(0xFFF0F0F0),
                                width: 1,
                              ) : null,
                              boxShadow: isUser ? [
                                BoxShadow(
                                  color: const Color(0xFFD62828).withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ] : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildRenderedMessage(message['content'] ?? '', isUser),
                                // Display attachments
                                if (message['attachments'] != null)
                                  for (final attachment in message['attachments'] as List<dynamic>)
                                    if (attachment['type'] == 'image')
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: GestureDetector(
                                            onTap: () => showDialog(
                                              context: context,
                                              builder: (_) => Dialog(
                                                child: InteractiveViewer(
                                                  child: Image.network(attachment['url'] ?? ''),
                                                ),
                                              ),
                                            ),
                                            child: Image.network(
                                              attachment['url'] ?? '',
                                              height: 160,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                // Timestamps intentionally hidden in chat UI per product request
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // Input area - Mobile messaging app style
          Container(
            color: Colors.white,
            padding: EdgeInsets.only(
              left: isMobile ? 12 : 24,
              right: isMobile ? 12 : 24,
              top: 12,
              bottom: keyboardHeight > 0 ? keyboardHeight + (isMobile ? 8 : 16) : (isMobile ? 8 : 16),
            ),
            child: SafeArea(
              top: false,
              child: Center(
                child: Container(
                  width: !isMobile ? MediaQuery.of(context).size.width * 0.5 : null, // 50% width on desktop
                  constraints: BoxConstraints(
                    maxHeight: isMobile ? 120 : 200, // Limit height on mobile
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                    border: Border.all(
                      color: const Color(0xFFE9ECEF),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: UriChatInput(
                    history: _messages.map((m) => {'role': m['role'] as String? ?? 'user', 'content': m['content'] as String? ?? ''}).toList(),
                    onMessage: (role, content, {attachments}) {
                      setState(() {
                        // We keep the list in reverse order (newest first) for the ListView with reverse: true
                        if (role == 'assistant') {
                          // If first message is an assistant bubble, replace its text (stream update)
                          if (_messages.isNotEmpty && _messages.first['role'] == 'assistant') {
                            _messages.first['content'] = content;
                          } else {
                            _messages.insert(0, {
                              'role': role,
                              'content': content,
                              'timestamp': DateTime.now(),
                              'id': '${role}_${_uuid.v4()}',
                              'attachments': attachments
                            });
                          }
                        } else {
                          // User messages also go at the front (newest first)
                          _messages.insert(0, {
                            'role': role,
                            'content': content,
                            'timestamp': DateTime.now(),
                            'id': '${role}_${_uuid.v4()}',
                            'attachments': attachments
                          });
                        }
                      });
                      _scrollToBottom();
                    },
                    onStreamStart: (cancelHandle) {
                      setState(() => _isLoading = true);
                    },
                    onStreamEnd: () {
                      setState(() => _isLoading = false);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: const Color(0xFFF0F0F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Uri is typing',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: const Color(0xFF1A1E3F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(3, (index) {
                        return AnimatedBuilder(
                          animation: _fadeController,
                          builder: (context, child) {
                            return Opacity(
                              opacity: (index * 0.3 + (_fadeController.value * 2) % 1.0) % 1.0,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD62828),
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
          ),
        ],
      ),
    );
  }
}

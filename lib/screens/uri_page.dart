import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../services/chat_service.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

class UriPage extends StatefulWidget {
  final bool embedded;
  const UriPage({Key? key, this.embedded = false}) : super(key: key);

  @override
  State<UriPage> createState() => _UriPageState();
}

class _UriPageState extends State<UriPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  late ChatService _chatService;
  String _currentAnswer = '';
  bool _sending = false;
  bool _isFirstInteraction = true;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(Uri.parse("https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatHttp"));
    _chatService.stream.listen((chunk) {
      if (chunk.error != null) {
        setState(() {
          _messages.add(_ChatMessage(role: Role.system, text: '[Error: ${chunk.error}]'));
          _sending = false;
        });
      } else if (chunk.done) {
        setState(() {
          if (_messages.isNotEmpty && _messages.last.role == Role.assistant) {
            _messages.last.streaming = false;
          }
          _sending = false;
        });
      } else if (chunk.delta != null) {
        setState(() => _currentAnswer += chunk.delta!);
        final normalizedAnswer = _normalizeMd(_currentAnswer);
        if (_messages.isNotEmpty && _messages.last.role == Role.assistant) {
          _messages.last.text = normalizedAnswer;
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    _scroll.dispose();
    _chatService.dispose();
    super.dispose();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(role: Role.user, text: text));
    });
    _scrollToBottom();
  }

  void _addAssistantPlaceholder() {
    setState(() {
      _messages.add(_ChatMessage(role: Role.assistant, text: '', streaming: true));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Render message text with LaTeX support.
  // We look for inline $...$ and block $$...$$ math and render using MathRenderer.
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
    print('=== NORMALIZING TEXT IN URI PAGE ===');
    print('Input: "${s.substring(0, math.min(300, s.length))}"');

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

    print('After critical fixes: "${s.substring(0, math.min(300, s.length))}"');

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

    print('Final normalized: "${s.substring(0, math.min(300, s.length))}"');
    return s.trim();
  }

  Widget _buildRenderedMessage(String text, bool isUser) {
    if (isUser) {
      return SelectableText(
        text, 
        style: GoogleFonts.montserrat(
          color: isUser ? Colors.white : const Color(0xFF111827), 
          fontSize: 15, 
          height: 1.45
        )
      );
    }

    // Normalize LaTeX delimiters first (same as URI chatbot)
    final normalizedText = normalizeLatex(text);

    // For AI responses, use SelectableText with proper styling
    return SelectableText(
      normalizedText,
      style: GoogleFonts.montserrat(
        color: const Color(0xFF111827), 
        fontSize: 15, 
        height: 1.5
      ),
    );
  }





  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    _addUserMessage(text);
    _addAssistantPlaceholder();
    // First interaction has occurred — bring input down to bottom
    if (_isFirstInteraction) {
      setState(() => _isFirstInteraction = false);
    }
    _currentAnswer = '';
    _sending = true;

    final user = FirebaseAuth.instance.currentUser;
    final idToken = user != null ? await user.getIdToken() : null;

    await _chatService.ask(
      message: text,
      history: [],
      extraHeaders: idToken != null ? {"Authorization": "Bearer $idToken"} : null,
    );
  }

  Widget _buildBubble(_ChatMessage m) {
    final isUser = m.role == Role.user;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.center;
    final bg = isUser ? const Color(0xFF0B5FFF) : Colors.white;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        // Center assistant bubbles and limit their width to a readable column
        // similar to ChatGPT. User messages remain right-aligned.
        Align(
          alignment: isUser ? Alignment.centerRight : Alignment.center,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            constraints: BoxConstraints(maxWidth: math.min(920, MediaQuery.of(context).size.width * 0.68)),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isUser
                  ? [BoxShadow(color: const Color(0xFF0B5FFF).withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 4))]
                  : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
              border: !isUser ? Border.all(color: const Color(0xFFE6E9EE), width: 1) : null,
            ),
            child: _buildRenderedMessage(m.text, isUser),
          ),
        ),
      ],
    );
  }

  // Clear local chat (clears on refresh also because state is local)
  void _clearChat() {
    setState(() {
      _messages.clear();
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Embedded mode: return only the page body so it can be placed inside the main app shell
    if (widget.embedded) {
      return Container(
        color: isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F7F8),
        child: Column(
          children: [
            // If this is the first interaction and there are no messages yet,
            // show a centered heading + input. After the first send, input moves to bottom.
            if (_isFirstInteraction && _messages.isEmpty)
              Expanded(child: _buildInitialPrompt())
            else ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, idx) {
                      final m = _messages[idx];
                      return _buildBubble(m);
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildInputArea(),
              const SizedBox(height: 6),
            ]
          ],
        ),
      );
    }

    // Default (standalone) mode keeps the Scaffold + AppBar
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1020) : const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0B1020) : Colors.white,
        elevation: 0.5,
        title: Text('Uri', style: GoogleFonts.montserrat(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Clear conversation',
            icon: Icon(Icons.delete_outline, color: isDark ? Colors.white70 : Colors.black87),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isFirstInteraction && _messages.isEmpty)
              Expanded(child: _buildInitialPrompt())
            else ...[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, idx) {
                      final m = _messages[idx];
                      return _buildBubble(m);
                    },
                  ),
                ),
              ),
              const Divider(height: 1),
              _buildInputArea(),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              // Shortcuts+Actions: Enter (without Shift) will invoke _send().
              // Shift+Enter will insert a newline as normal in the multiline TextField.
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  // SingleActivator defaults to requiring no modifiers.
                  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    ActivateIntent: CallbackAction(onInvoke: (intent) {
                      // Only send when Enter is pressed without Shift. SingleActivator
                      // ensures Shift is not pressed.
                      _send();
                      return null;
                    }),
                  },
                  child: Focus(
                    focusNode: _inputFocusNode,
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: 'Ask Uri AI...',
                        filled: true,
                        fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B1020) : Colors.white,
                        hintStyle: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[500]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      // onSubmitted kept for platforms that treat enter as submit
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0B5FFF),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF0B5FFF).withOpacity(0.14), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: IconButton(
                onPressed: _send,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialPrompt() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName ?? user?.email?.split('@').first ?? 'Student';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$name — What do you want to study?',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1E3F),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Ask Uri about a topic, question or concept...',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0B1020) : Colors.white,
                        hintStyle: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[500]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B5FFF),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: const Color(0xFF0B5FFF).withOpacity(0.14), blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: IconButton(
                      onPressed: _send,
                      icon: _sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum Role { user, assistant, system }

class _ChatMessage {
  Role role;
  String text;
  bool streaming;
  _ChatMessage({required this.role, required this.text, this.streaming = false});
}





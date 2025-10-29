import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/chat_service.dart';
import 'dart:math' as math;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter/services.dart';
import '../services/uri_normalizer.dart';

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
  bool _aggressiveClean = false;

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
        final normalizedAnswer = normalizeMd(_currentAnswer);
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
  // Normalization and splitting helpers moved to `lib/services/uri_normalizer.dart`.

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
    final normalizedText = normalizeLatex(text, aggressive: _aggressiveClean);

    // Render markdown with LaTeX support by splitting into segments
    // provided by `splitIntoSegments` in the normalizer service.
    return _renderMarkdownWithMath(normalizedText);
  }

  Widget _renderMarkdownWithMath(String text) {
    final children = <Widget>[];
    final segments = splitIntoSegments(text);
    for (final seg in segments) {
      if (seg.isMath) {
        if (seg.isBlock) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Math.tex(seg.text, textStyle: GoogleFonts.montserrat(fontSize: 16), mathStyle: MathStyle.display),
          ));
        } else {
                children.add(InlineMathWidget(seg.text));
        }
      } else {
        children.add(_markdownSegment(seg.text));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((w) => Padding(padding: const EdgeInsets.symmetric(vertical: 2.0), child: w)).toList(),
    );
  }

  // Wrap markdown text in a small constrained MarkdownBody to get
  // nice formatting (headers, bold, lists). We use selectable=false
  // because the surrounding bubble provides selection.
  Widget _markdownSegment(String md) {
    return MarkdownBody(
      data: md,
      selectable: false,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: GoogleFonts.montserrat(fontSize: 15, height: 1.5, color: const Color(0xFF111827)),
        h3: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1A1E3F)),
      ),
      onTapLink: (text, href, title) {
        // noop for now
      },
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
            tooltip: _aggressiveClean ? 'Aggressive cleaning: ON' : 'Aggressive cleaning: OFF',
            icon: Icon(Icons.auto_fix_high, color: _aggressiveClean ? Colors.amberAccent : (isDark ? Colors.white70 : Colors.black87)),
            onPressed: () {
              setState(() => _aggressiveClean = !_aggressiveClean);
              final snack = SnackBar(content: Text('Aggressive cleanup ${_aggressiveClean ? 'enabled' : 'disabled'}'));
              ScaffoldMessenger.of(context).showSnackBar(snack);
            },
          ),
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


// A small widget to render inline math using flutter_math_fork in a row
class InlineMathWidget extends StatelessWidget {
  final String latex;
  const InlineMathWidget(this.latex, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Math.tex(latex, textStyle: GoogleFonts.montserrat(fontSize: 15), mathStyle: MathStyle.text),
      ],
    );
  }
}





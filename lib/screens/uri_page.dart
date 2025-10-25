import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import '../services/uri_ai_sse_io.dart';
import 'dart:async';

class UriPage extends StatefulWidget {
  final bool embedded;
  const UriPage({Key? key, this.embedded = false}) : super(key: key);

  @override
  State<UriPage> createState() => _UriPageState();
}

class _UriPageState extends State<UriPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_ChatMessage> _messages = [];
  CancelHandle? _currentCancel;
  bool _sending = false;
  bool _isFirstInteraction = true;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _currentCancel?.cancel();
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

  void _appendToAssistant(String chunk) {
    // Normalize incoming chunk (server may send JSON fragments like arrays/objects)
    final text = _normalizeChunk(chunk);

    setState(() {
      final last = _messages.lastWhere((m) => m.role == Role.assistant, orElse: () => _ChatMessage(role: Role.assistant, text: '', streaming: false));
      // Add spacing if needed between existing text and new chunk
      if (last.text.isNotEmpty && text.isNotEmpty) {
        final endsWithSpace = RegExp(r"\s$").hasMatch(last.text);
        final startsWithSpace = RegExp(r"^\s").hasMatch(text);
        if (!endsWithSpace && !startsWithSpace) {
          last.text += ' ';
        }
      }
      last.text += text;
    });
    _scrollToBottom();
  }

  String _normalizeChunk(String chunk) {
    // Trim and remove obvious trailing markers
    var s = chunk.trim();

    // Try to decode JSON and extract text leaves
    try {
      final decoded = jsonDecode(s);
      final extracted = _extractTextFromJson(decoded);
      if (extracted.isNotEmpty) return extracted;
    } catch (_) {
      // not JSON — fall through
    }

    // Remove trailing empty array markers like []
    if (s.endsWith('[]')) s = s.substring(0, s.length - 2).trimRight();

    return s;
  }

  String _extractTextFromJson(dynamic node) {
    if (node == null) return '';
    if (node is String) return node;
    if (node is num) return node.toString();
    if (node is List) {
      return node.map((e) => _extractTextFromJson(e)).where((t) => t.isNotEmpty).join(' ');
    }
    if (node is Map) {
      // Common fields used by various SSE payloads
      final candidates = <String>[];
      if (node.containsKey('text')) candidates.add(node['text'].toString());
      if (node.containsKey('delta')) candidates.add(node['delta'].toString());
      if (node.containsKey('content')) candidates.add(node['content'].toString());
      if (node.containsKey('message')) candidates.add(node['message'].toString());
      if (node.containsKey('data')) candidates.add(node['data'].toString());

      if (candidates.isNotEmpty) return candidates.where((s) => s.isNotEmpty).join(' ');

      // Otherwise recursively collect
      return node.values.map((v) => _extractTextFromJson(v)).where((t) => t.isNotEmpty).join(' ');
    }
    return '';
  }

  void _finishAssistant() {
    setState(() {
      final idx = _messages.lastIndexWhere((m) => m.role == Role.assistant);
      if (idx != -1) {
        _messages[idx].streaming = false;
      }
      _sending = false;
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
    _sending = true;

    final user = FirebaseAuth.instance.currentUser;
    final idToken = user != null ? await user.getIdToken() : null;
    final conversationId = user?.uid ?? DateTime.now().millisecondsSinceEpoch.toString();

    // cancel previous streaming if any
    _currentCancel?.cancel();
    try {
      _currentCancel = await streamAskSSE_impl(
        text,
        (chunk) {
          // SSE may send JSON frames; for safety treat as raw chunk
          if (chunk == '[DONE]') return;
          _appendToAssistant(chunk);
        },
        onDone: () {
          _finishAssistant();
        },
        onError: (err) {
          _finishAssistant();
          setState(() {
            _messages.add(_ChatMessage(role: Role.system, text: '[Error: $err]'));
          });
        },
        idToken: idToken,
        conversationId: conversationId,
      );
    } catch (e) {
      _finishAssistant();
      setState(() {
        _messages.add(_ChatMessage(role: Role.system, text: '[Error initiating stream]'));
      });
    }
  }

  Widget _buildBubble(_ChatMessage m) {
    final isUser = m.role == Role.user;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bg = isUser ? const Color(0xFF0B5FFF) : Colors.white;
    final textColor = isUser ? Colors.white : const Color(0xFF111827);
    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isUser
                ? [BoxShadow(color: const Color(0xFF0B5FFF).withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 4))]
                : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
            border: !isUser ? Border.all(color: const Color(0xFFE6E9EE), width: 1) : null,
          ),
          child: SelectableText(
            m.text,
            style: GoogleFonts.montserrat(color: textColor, fontSize: 15, height: 1.45),
          ),
        ),
      ],
    );
  }

  // Clear local chat (clears on refresh also because state is local)
  void _clearChat() {
    setState(() {
      _currentCancel?.cancel();
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
                onSubmitted: (_) => _send(),
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

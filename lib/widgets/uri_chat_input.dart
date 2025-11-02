import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';

class UriChatInput extends StatefulWidget {
  final FutureOr<void> Function(String role, String content, {List<Map<String, String>>? attachments}) onMessage;
  final List<Map<String, String>> history;
  final void Function(dynamic cancelHandle)? onStreamStart;
  final void Function()? onStreamEnd;

  const UriChatInput({super.key, required this.onMessage, required this.history, this.onStreamStart, this.onStreamEnd});

  @override
  State<UriChatInput> createState() => _UriChatInputState();
}

class _UriChatInputState extends State<UriChatInput> {
  final _input = TextEditingController();
  String _currentAnswer = '';
  bool _loading = false;
  String? _error;
  late ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = ChatService(Uri.parse(
      "https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatHttp",
    ));
    _chatService.stream.listen((chunk) {
      debugPrint('Received chunk: ${chunk.delta != null ? 'text' : chunk.done ? 'done' : chunk.error != null ? 'error' : 'unknown'}');
      if (chunk.error != null) {
        debugPrint('Stream error: ${chunk.error}');
        setState(() {
          _error = chunk.error;
          _loading = false;
        });
        widget.onMessage('assistant', 'Sorry, I couldn\'t process that right now. Error: ${chunk.error}');
        return;
      }
      if (chunk.done) {
        debugPrint('Stream completed');
        setState(() => _loading = false);
        if (widget.onStreamEnd != null) widget.onStreamEnd!();
        return;
      }
      if (chunk.delta != null) {
        debugPrint('Received delta: "${chunk.delta}"');
        setState(() => _currentAnswer += chunk.delta!);
        // Apply normalization to the full accumulated answer
        final normalizedAnswer = _normalizeMd(_currentAnswer);
        widget.onMessage('assistant', normalizedAnswer);
      }
    });
  }

  @override
  void dispose() {
    _chatService.dispose();
    _input.dispose();
    super.dispose();
  }

  String _normalizeMd(String s) {
    debugPrint('=== NORMALIZING TEXT ===');
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
    s = s.replaceAllMapped(RegExp(r'(\d+)\*\*([^*]+)\*\*:'), (match) => '${match.group(1)}. **${match.group(2)}**:');

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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;

    _input.clear();
    setState(() {
      _currentAnswer = '';
      _error = null;
      _loading = true;
    });

    // Send user message to UI
    widget.onMessage('user', text);

    // Initialize assistant message
    widget.onMessage('assistant', '');

    // Notify stream start
    if (widget.onStreamStart != null) widget.onStreamStart!(null);

    // Get Firebase auth token
    final user = FirebaseAuth.instance.currentUser;
    final idToken = user != null ? await user.getIdToken() : null;

    await _chatService.ask(
      message: text,
      history: widget.history,
      extraHeaders: idToken != null ? {"Authorization": "Bearer $idToken"} : null,
    );
  }



  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_error != null)
          MaterialBanner(
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            content: Text(_error!),
            actions: [
              TextButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss'))
            ],
          ),
        Row(
          children: [
            Expanded(
              child: Shortcuts(
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                },
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    ActivateIntent: CallbackAction(onInvoke: (intent) {
                      _send();
                      return null;
                    }),
                  },
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Ask Uri anything…',
                      border: OutlineInputBorder(borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: _loading ? const CircularProgressIndicator() : const Icon(Icons.send),
              onPressed: _loading ? null : _send,
            ),
          ],
        ),
      ],
    );
  }
}

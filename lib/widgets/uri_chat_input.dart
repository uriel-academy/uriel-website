import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/uri_ai_sse_io.dart';

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
  final _ctrl = TextEditingController();
  bool _sending = false;
  dynamic _cancelHandle;

  String _normalizeChunk(String chunk) {
    // Normalize incoming chunk (server may send JSON fragments like arrays/objects)
    final text = _extractTextFromJson(chunk);
    if (text.isNotEmpty) return text;

    // Try to decode JSON and extract text leaves
    try {
      final decoded = jsonDecode(chunk);
      final extracted = _extractTextFromJson(decoded);
      if (extracted.isNotEmpty) return extracted;
    } catch (_) {
      // not JSON — fall through
    }

    // Remove any NUL bytes that sometimes appear in streams
    var s = chunk.replaceAll('\u0000', '');
    // Remove trailing empty-array/object markers like [] or {} which can appear repeatedly.
    // Keep surrounding whitespace intact where possible.
    s = s.replaceAll(RegExp(r'(?:\[\s*\]|\{\s*\})+\s*$'), '');

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

  Future<void> _sendText() async {
    var text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    // Clear the UI state
    _ctrl.clear();

    // Get Firebase auth token for authentication like URI page
    final user = FirebaseAuth.instance.currentUser;
    final idToken = user != null ? await user.getIdToken() : null;
    final conversationId = user?.uid ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Send the user message to the parent UI
    widget.onMessage('user', text);

    String accumulated = '';
    // create assistant bubble (will be updated by stream)
    widget.onMessage('assistant', '');

    dynamic cancelHandle;
    try {
      // Use streamAskSSE_impl directly with authentication like URI page
      cancelHandle = await streamAskSSE_impl(
        text, // Only send current message, not full history
        (chunk) {
          // Normalize incoming chunk like URI page does
          final normalizedChunk = _normalizeChunk(chunk);
          accumulated += normalizedChunk;
          widget.onMessage('assistant', accumulated);
        },
        onDone: () {
          // finalize — nothing special to do
        },
        onError: (err) {
          widget.onMessage('assistant', 'Sorry, I couldn\'t process that right now.');
        },
        idToken: idToken,
        conversationId: conversationId,
      );
      if (cancelHandle != null && widget.onStreamStart != null) {
        _cancelHandle = cancelHandle;
        widget.onStreamStart!(cancelHandle);
      }
    } catch (e) {
      widget.onMessage('assistant', 'Sorry, I couldn\'t process that right now.');
    } finally {
      setState(() => _sending = false);
      // If we had a cancel handle, clear it and call onStreamEnd
      if (_cancelHandle != null) {
        _cancelHandle = null;
      }
      if (widget.onStreamEnd != null) widget.onStreamEnd!();
    }
  }



  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: 'Ask Uri anything…',
              border: OutlineInputBorder(borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white,
            ),
            minLines: 1,
            maxLines: 6,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendText(),
          ),
        ),

        IconButton(
          icon: _sending
              ? (_cancelHandle != null ? const Icon(Icons.stop) : const CircularProgressIndicator())
              : const Icon(Icons.send),
          onPressed: _sending
              ? () {
                  // Cancel stream if available
                  try {
                    _cancelHandle?.cancel();
                  } catch (_) {}
                  setState(() => _sending = false);
                }
              : _sendText,
        ),
      ],
    );
  }
}

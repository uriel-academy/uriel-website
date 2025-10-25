import 'dart:async';
import 'package:flutter/material.dart';
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
  final _ctrl = TextEditingController();
  bool _sending = false;
  dynamic _cancelHandle;
  final _chat = ChatService();

  Future<void> _sendText() async {
    var text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);

    // Clear the UI state
    _ctrl.clear();

    // Send the user message to the parent UI
    widget.onMessage('user', text);
    final history = [...widget.history, {'role': 'user', 'content': text}];

    String accumulated = '';
    // create assistant bubble (will be updated by stream)
    widget.onMessage('assistant', '');

    dynamic cancelHandle;
    try {
      cancelHandle = await _chat.sendStream(
        messages: history,
        channel: 'uri_tab',
        profile: {
          'name': 'Student',
          'level': 'JHS',
          'locale': 'en-GH',
        },
        onChunk: (chunk) {
          accumulated += chunk;
          widget.onMessage('assistant', accumulated);
        },
        onDone: () {
          // finalize — nothing special to do
        },
        onError: (err) {
          widget.onMessage('assistant', 'Sorry, I couldn\'t process that right now.');
        },
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

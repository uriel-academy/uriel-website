import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/chat_service.dart';
import '../services/image_storage.dart';

class UriChatInput extends StatefulWidget {
  final void Function(String role, String content) onMessage;
  final List<Map<String, String>> history;

  const UriChatInput({super.key, required this.onMessage, required this.history});

  @override
  State<UriChatInput> createState() => _UriChatInputState();
}

class _UriChatInputState extends State<UriChatInput> {
  final _ctrl = TextEditingController();
  bool _sending = false;
  final _picker = ImagePicker();
  final _chat = ChatService();
  final _store = ImageStorage();

  Future<void> _sendText() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _ctrl.clear();

    widget.onMessage('user', text);
    final history = [...widget.history, {'role': 'user', 'content': text}];

    try {
      final reply = await _chat.send(messages: history, channel: 'uri_tab', profile: {
        'name': 'Student',
        'level': 'JHS',
        'locale': 'en-GH',
      });
      widget.onMessage('assistant', reply);
    } catch (e) {
      widget.onMessage('assistant', 'Sorry, I couldn\'t process that right now.');
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 2000);
      if (x == null) return;

      final bytes = await x.readAsBytes();
      final url = await _store.uploadBytes(bytes as Uint8List, x.name);

      widget.onMessage('user', '[Image] $url');

      final history = [...widget.history, {'role': 'user', 'content': 'Please analyze this image.'}];

      setState(() => _sending = true);
      final reply = await _chat.send(
        messages: history,
        imageUrl: url,
        channel: 'uri_tab',
        profile: {'name': 'Student', 'level': 'JHS', 'locale': 'en-GH'},
      );
      widget.onMessage('assistant', reply);
    } catch (e) {
      widget.onMessage('assistant', 'Image upload failed. Try a smaller file (.jpg/.png).');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PopupMenuButton<String>(
          tooltip: 'Attach',
          icon: const Icon(Icons.attach_file),
          onSelected: (v) {
            if (v == 'camera') _pickAndSendImage(ImageSource.camera);
            if (v == 'gallery') _pickAndSendImage(ImageSource.gallery);
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'camera', child: Text('Camera')),
            PopupMenuItem(value: 'gallery', child: Text('Photo / File')),
          ],
        ),

        Expanded(
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              hintText: 'Ask Uri anything…',
              border: OutlineInputBorder(borderSide: BorderSide.none),
            ),
            minLines: 1,
            maxLines: 6,
            onSubmitted: (_) => _sendText(),
          ),
        ),

        IconButton(
          icon: _sending ? const CircularProgressIndicator() : const Icon(Icons.send),
          onPressed: _sending ? null : _sendText,
        ),
      ],
    );
  }
}

import 'dart:typed_data';
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
  Uint8List? _pendingImage;
  String? _pendingImageName;

  Future<void> _sendText() async {
    var text = _ctrl.text.trim();
    if (text.isEmpty && _pendingImage == null) return;

    setState(() => _sending = true);

    String? uploadedUrl;
    if (_pendingImage != null && _pendingImageName != null) {
      // Upload the pending image first
      try {
        uploadedUrl = await _store.uploadBytes(_pendingImage!, _pendingImageName!);
      } catch (e) {
        widget.onMessage('assistant', 'Image upload failed. Try a smaller file or different format.');
        setState(() => _sending = false);
        return;
      }
    }

    // If user included a placeholder like [Image], remove it before sending
    if (uploadedUrl != null) {
      // Append a short hint to the message so server knows to analyze image unless user provided explicit text
      if (text.isEmpty) text = 'Please analyze this image.';
    }

    // Clear the UI state
    _ctrl.clear();
    setState(() {
      _pendingImage = null;
      _pendingImageName = null;
    });

    // Send the user message and image URL (if any) to the backend
    widget.onMessage('user', text + (uploadedUrl != null ? '\n[Image] $uploadedUrl' : ''));
    final history = [...widget.history, {'role': 'user', 'content': text}];

    try {
      final reply = await _chat.send(messages: history, imageUrl: uploadedUrl, channel: 'uri_tab', profile: {
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
      final x = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 4000);
      if (x == null) return;

      final bytes = await x.readAsBytes();

      // If file is too large client-side, prompt user
      if (bytes.lengthInBytes > 25 * 1024 * 1024) {
        widget.onMessage('assistant', 'Selected file is larger than 25MB. Please choose a smaller image.');
        return;
      }

      // Store pending image and show preview in the input area. Actual upload will occur when user presses send.
      setState(() {
        _pendingImage = bytes;
        _pendingImageName = x.name;
      });

      // Insert a short placeholder into the text box so user knows an image is attached
      _ctrl.text = '${_ctrl.text}${_ctrl.text.isEmpty ? '' : '\n'}[Attached image: ${x.name}]';
      _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
    } catch (e) {
      widget.onMessage('assistant', 'Image pick failed. Try again.');
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pendingImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Image.memory(_pendingImage!, width: 64, height: 64, fit: BoxFit.cover),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_pendingImageName ?? 'Attached image')),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _pendingImage = null;
                            _pendingImageName = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                  hintText: 'Ask Uri anything…',
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                minLines: 1,
                maxLines: 6,
                onSubmitted: (_) => _sendText(),
              ),
            ],
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

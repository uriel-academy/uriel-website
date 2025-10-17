import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class UriChat extends StatefulWidget {
  final String? userName;
  const UriChat({Key? key, this.userName}) : super(key: key);

  @override
  UriChatState createState() => UriChatState();
}

class UriChatState extends State<UriChat> with SingleTickerProviderStateMixin {
  bool _open = false;
  final _messages = <Map<String, String>>[]; // {role: 'user'|'bot', text: '...'}
  final _ctrl = TextEditingController();
  bool _loading = false;

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

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _messages.insert(0, {'role':'user','text':text}); _loading = true; _ctrl.clear(); });

    try {
  // Use region-specific instance to ensure we call the correct function URL
  final callable = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('aiChat');
      final payload = <String, dynamic>{ 'message': text, 'mode': 'chat' };
      if (widget.userName != null) payload['userName'] = widget.userName;
      final resp = await callable.call(payload);
      final data = resp.data as Map<String, dynamic>;
      final reply = data['reply'] as String? ?? 'No reply';
      setState(() { _messages.insert(0, {'role':'bot','text':reply}); });
    } on FirebaseFunctionsException catch (e) {
      setState(() { _messages.insert(0, {'role':'bot','text':'AI error: ${e.message ?? e.code}'}); });
    } catch (e) {
      setState(() { _messages.insert(0, {'role':'bot','text':'Error: ${e.toString()}'}); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      right: 0,
      top: 100,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_open) _buildSheet(context),
            GestureDetector(
              onTap: _toggle,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(_open ? 'Close uri' : 'uri', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.6;
    return Container(
      width: 420,
      height: height,
      margin: const EdgeInsets.only(right: 12, bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const CircleAvatar(child: Text('u')),
                const SizedBox(width: 8),
                Expanded(child: Text('${widget.userName ?? 'uri'} — study assistant', style: const TextStyle(fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.minimize), onPressed: _toggle),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _messages.isEmpty
              ? const Center(child: Text('Hi — ask me anything about BECE & WASSCE subjects.'))
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) {
                    final m = _messages[i];
                    final isUser = m['role'] == 'user';
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blueAccent : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(m['text'] ?? '', style: TextStyle(color: isUser ? Colors.white : Colors.black87)),
                      ),
                    );
                  },
                ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(hintText: 'Ask uri...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _loading ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())
                  : IconButton(icon: const Icon(Icons.send), onPressed: _send),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

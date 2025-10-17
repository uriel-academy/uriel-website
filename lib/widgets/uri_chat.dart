import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    _bounceController.forward();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

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
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');
      final idToken = await user.getIdToken();
      const url = 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatHttp';
      final payload = <String, dynamic>{ 'message': text, 'mode': 'chat' };
      if (widget.userName != null) payload['userName'] = widget.userName;
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'Origin': 'https://uriel.academy', // or get from window.location.origin if needed
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = data['reply'] as String? ?? 'No reply';
        setState(() { _messages.insert(0, {'role':'bot','text':reply}); });
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      setState(() { _messages.insert(0, {'role':'bot','text':'AI error: ${e.toString()}'}); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final buttonSize = isMobile ? 56.0 : 64.0;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      right: 0,
      bottom: _open ? (isMobile ? MediaQuery.of(context).size.height * 0.15 : 20) : 20,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_open) _buildSheet(context),
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bounceAnimation.value,
                  child: child,
                );
              },
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggle,
                  borderRadius: BorderRadius.circular(buttonSize / 2),
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheet(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final height = isMobile ? MediaQuery.of(context).size.height * 0.85 : 600.0;
    final width = isMobile ? MediaQuery.of(context).size.width : 400.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: width,
      height: height,
      margin: EdgeInsets.only(
        right: isMobile ? 0 : 20,
        bottom: isMobile ? 0 : 20,
        left: isMobile ? 0 : MediaQuery.of(context).size.width - width - 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: isMobile
            ? const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))
            : BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: isMobile
                  ? const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))
                  : const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Text('🦉', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Chat with Uri',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.minimize),
                  onPressed: _toggle,
                  tooltip: 'Minimize',
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _open = false;
                      _messages.clear();
                    });
                  },
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _messages.isEmpty && !_loading
                ? const Center(child: Text('Hi — ask me anything about BECE & WASSCE subjects.'))
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (_loading && i == 0) {
                        return _buildTypingIndicator();
                      }
                      final m = _messages[i - (_loading ? 1 : 0)];
                      final isUser = m['role'] == 'user';
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(maxWidth: width * 0.8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? Theme.of(context).primaryColor : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            m['text'] ?? '',
                            style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Ask Uri...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _loading ? null : _send,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Uri is typing', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _bounceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: (index * 0.3 + _bounceController.value) % 1.0,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade600,
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
    );
  }
}

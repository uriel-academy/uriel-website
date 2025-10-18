import 'package:flutter/material.dart';
import '../widgets/uri_chat.dart';

class UriChatDemoPage extends StatelessWidget {
  const UriChatDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('uri — chat demo')),
      body: const Stack(
        children: [
          Center(child: Text('Open the chat using the button at bottom-right.')),
          // The UriChat widget is positioned with AnimatedPositioned and will float above the UI
          UriChat(),
        ],
      ),
    );
  }
}

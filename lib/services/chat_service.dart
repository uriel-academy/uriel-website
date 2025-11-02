import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatChunk {
  final String? delta;   // new text token
  final bool done;
  final String? error;
  final Map<String, dynamic>? meta;

  ChatChunk({this.delta, this.done = false, this.error, this.meta});

  factory ChatChunk.fromJson(Map<String, dynamic> map) {
    final type = map['type'];
    if (type == 'text') return ChatChunk(delta: map['delta'] as String?);
    if (type == 'done') return ChatChunk(done: true);
    if (type == 'error') return ChatChunk(error: map['message'] as String?);
    if (type == 'meta') return ChatChunk(meta: Map<String, dynamic>.from(map));
    return ChatChunk();
  }
}

class ChatService {
  final _controller = StreamController<ChatChunk>.broadcast();
  Stream<ChatChunk> get stream => _controller.stream;

  /// Call your deployed function URL
  /// Example:
  ///   https://us-central1-<project-id>.cloudfunctions.net/aiChatHttp
  final Uri endpoint;

  ChatService(this.endpoint);

  Future<void> ask({
    required String message,
    String? system,
    String? imageBase64,
    List<Map<String, String>> history = const [],
    Map<String, String>? extraHeaders,
  }) async {
    print('ChatService.ask called with message: "$message"');
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
        ...?extraHeaders,
      };

      final body = jsonEncode({
        "message": message,
        if (system != null) "system": system,
        if (imageBase64 != null) "imageBase64": imageBase64,
        if (history.isNotEmpty) "history": history, // [{role, content}]
      });

      print('Sending request to $endpoint with body: $body');

      final request = http.Request('POST', endpoint)
        ..headers.addAll(headers)
        ..body = body;

      final streamedResponse = await request.send();
      print('Response status: ${streamedResponse.statusCode}');

      // If not 200/SSE, read and emit error then return
      if (streamedResponse.statusCode != 200) {
        final err = await streamedResponse.stream.bytesToString();
        print('Error response: $err');
        _controller.add(ChatChunk(error: "HTTP ${streamedResponse.statusCode}: $err"));
        return;
      }

      // Parse SSE lines
      final utf8Stream = streamedResponse.stream.transform(utf8.decoder);
      final lineStream = const LineSplitter().bind(utf8Stream);

      await for (final line in lineStream) {
        print('SSE line: "$line"');
        if (line.startsWith(':')) {
          // comment/heartbeat -> ignore
          continue;
        }
        if (line.startsWith('data: ')) {
          final jsonStr = line.substring(6);
          if (jsonStr.isEmpty) continue;
          print('Processing data: "$jsonStr"');
          try {
            final map = jsonDecode(jsonStr) as Map<String, dynamic>;
            _controller.add(ChatChunk.fromJson(map));
          } catch (e) {
            print('Failed to parse JSON: $e');
            // ignore malformed chunk
          }
        }
        // blank lines separate events; we don't need special handling
      }
      print('SSE stream ended');
    } catch (e) {
      print('ChatService error: $e');
      _controller.add(ChatChunk(error: e.toString()));
    }
  }

  void dispose() {
    _controller.close();
  }
}

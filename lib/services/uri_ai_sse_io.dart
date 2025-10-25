// IO (non-web) SSE/fetch-stream fallback implementation
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

/// A simple cancel handle for IO streaming
class CancelHandle {
  final void Function() _cancel;
  CancelHandle(this._cancel);
  void cancel() => _cancel();
}

/// Stream to `aiChatSSE` for IO platforms (non-web).
/// Sends optional `idToken` as Authorization header and `conversationId` in the request body.
/// onData receives raw SSE payload chunks (usually text fragments).
Future<CancelHandle> streamAskSSE_impl(
  String prompt,
  void Function(String chunk) onData, {
  void Function()? onDone,
  void Function(Object error)? onError,
  String? imageUrl,
  String? idToken,
  String? conversationId,
  bool? useWebSearch,
  bool? useMathJax,
}) async {
  final uri = Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatSSE');
  final req = http.Request('POST', uri);
  req.headers['Content-Type'] = 'application/json';
  if (idToken != null && idToken.isNotEmpty) {
    req.headers['Authorization'] = 'Bearer $idToken';
  }

  final body = {
    'message': prompt,
    if (imageUrl != null) 'image_url': imageUrl,
    if (conversationId != null) 'conversationId': conversationId,
    if (useWebSearch == true) 'useWebSearch': true,
    if (useMathJax == true) 'useMathJax': true,
  };
  req.body = jsonEncode(body);

  final streamed = await req.send();
  final controller = StreamController<bool>();

  // Listen to response stream and parse SSE-style lines (data: ...)
  // Simple SSE parser: handle 'event:' and 'data:' lines and dispatch on blank line.
  String? currentEvent;
  final sb = StringBuffer();

  final sub = streamed.stream.transform(utf8.decoder).listen((chunk) {
    if (chunk.isEmpty) return;
    final lines = chunk.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        sb.write(line.substring(5));
        sb.write('\n');
      } else if (line.trim().isEmpty) {
        // dispatch
        final payload = sb.toString().trim();
        if (payload.isNotEmpty) {
          try {
            if (currentEvent == 'web_verified') {
              // payload is JSON like { answer: '...' }
              try {
                final decoded = jsonDecode(payload);
                final answer = decoded is Map && decoded['answer'] != null ? decoded['answer'].toString() : payload;
                onData('[Web-verified answer]\n' + answer);
              } catch (_) {
                onData('[Web-verified]\n' + payload);
              }
            } else {
              onData(payload);
            }
          } catch (_) {}
        }
        // reset
        currentEvent = null;
        sb.clear();
      } else {
        // non-prefixed line - append as-is (some providers send raw chunks)
        sb.write(line);
        sb.write('\n');
      }
    }
  }, onDone: () {
    if (onDone != null) onDone();
    controller.close();
  }, onError: (e) {
    if (onError != null) onError(e);
    controller.close();
  }, cancelOnError: true);

  return CancelHandle(() async {
    try {
      await sub.cancel();
    } catch (_) {}
    try {
      await controller.close();
    } catch (_) {}
  });
}

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
  };
  req.body = jsonEncode(body);

  final streamed = await req.send();
  final controller = StreamController<bool>();

  // Listen to response stream and parse SSE-style lines (data: ...)
  final sub = streamed.stream.transform(utf8.decoder).listen((chunk) {
    if (chunk.trim().isEmpty) return;
    // The server may send partial pieces; split on newlines and handle data: frames.
    final lines = chunk.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      if (line.startsWith('data:')) {
        final payload = line.substring(5).trim();
        if (payload.isNotEmpty) {
          try {
            onData(payload);
          } catch (_) {
            // swallow UI errors from onData
          }
        }
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

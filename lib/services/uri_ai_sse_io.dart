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

Future<CancelHandle> streamAskSSE_impl(String prompt, void Function(String chunk) onData, {void Function()? onDone, void Function(Object error)? onError}) async {
  final req = http.Request('POST', Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatSSE'));
  req.headers['Content-Type'] = 'application/json';
  req.body = jsonEncode({'message': prompt});
  final streamed = await req.send();
  final controller = StreamController<bool>();

  // Listen to response stream
  final sub = streamed.stream.transform(utf8.decoder).listen((chunk) {
    if (chunk.trim().isEmpty) return;
    final lines = chunk.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      if (line.startsWith('data:')) {
        final payload = line.substring(5).trim();
        if (payload.isNotEmpty) onData(payload);
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
    try { await sub.cancel(); } catch (_) {}
    try { await controller.close(); } catch (_) {}
  });
}

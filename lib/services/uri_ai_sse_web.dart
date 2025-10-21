// Web-specific SSE implementation
// Uses dart:html EventSource
import 'dart:html' as html;

/// A simple cancel handle that allows the caller to stop the stream.
class CancelHandle {
  final void Function() _cancel;
  CancelHandle(this._cancel);
  void cancel() => _cancel();
}

Future<CancelHandle> streamAskSSE_impl(String prompt, void Function(String chunk) onData, {void Function()? onDone, void Function(Object error)? onError}) async {
  final uri = Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatSSE')
      .replace(queryParameters: {'message': prompt});
  final es = html.EventSource(uri.toString());
  final sub = es.onMessage.listen((e) {
    final data = e.data ?? '';
    if (data.isNotEmpty) onData(data);
  }, onError: (err) {
    if (onError != null) onError(err ?? Exception('SSE error'));
  }, onDone: () {
    try { es.close(); } catch (_) {}
    if (onDone != null) onDone();
  });

  // Return a cancel handle that closes the EventSource and cancels subscription
  return CancelHandle(() {
    try { sub.cancel(); } catch (_) {}
    try { es.close(); } catch (_) {}
  });
}

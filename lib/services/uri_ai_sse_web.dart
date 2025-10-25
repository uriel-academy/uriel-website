// Web-specific SSE implementation
// Uses dart:html EventSource
import 'dart:html' as html;

/// A simple cancel handle that allows the caller to stop the stream.
class CancelHandle {
  final void Function() _cancel;
  CancelHandle(this._cancel);
  void cancel() => _cancel();
}

Future<CancelHandle> streamAskSSE_impl(String prompt, void Function(String chunk) onData, {void Function()? onDone, void Function(Object error)? onError, String? imageUrl, bool? useWebSearch, bool? useMathJax}) async {
  final params = {'message': prompt};
  if (imageUrl != null) params['image_url'] = imageUrl;
  if (useWebSearch == true) params['useWebSearch'] = 'true';
  if (useMathJax == true) params['useMathJax'] = 'true';
  final uri = Uri.parse('https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChatSSE')
      .replace(queryParameters: params);
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

  // Listen for web_verified custom SSE event
  try {
    es.addEventListener('web_verified', (e) {
      try {
        final me = e as html.MessageEvent;
        final data = me.data ?? '';
        if (data != null && data.toString().isNotEmpty) {
          try {
            final parsed = jsonDecode(data.toString());
            final answer = parsed is Map && parsed['answer'] != null ? parsed['answer'].toString() : data.toString();
            onData('[Web-verified answer]\n' + answer);
          } catch (_) {
            onData('[Web-verified]\n' + data.toString());
          }
        }
      } catch (_) {}
    });
  } catch (_) {}

  // Return a cancel handle that closes the EventSource and cancels subscription
  return CancelHandle(() {
    try { sub.cancel(); } catch (_) {}
    try { es.close(); } catch (_) {}
  });
}

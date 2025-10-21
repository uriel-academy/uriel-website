import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'uri_ai_sse.dart';
export 'uri_ai_sse.dart';

const _aiUrl = 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChat';
const _factsUrl = 'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/facts';

String simplifyMath(String text) {
  // Keep LaTeX/KaTeX markup intact; only normalize line endings and trim.
  return text.replaceAll(RegExp(r'\r\n'), '\n').trim();
}

bool _needsWeb(String q) {
  final s = q.toLowerCase();
  return [
    'when is', 'date', 'schedule', 'deadline', 'latest', 'today', 'this year',
    'bece', 'wassce', 'nacca', 'curriculum update', 'exam timetable',
    'minister announced', 'news', '2025', '2026'
  ].any((k) => s.contains(k));
}

class UriAI {
  static Future<String> ask(String prompt) async {
    final useFacts = _needsWeb(prompt);
    final uri = Uri.parse(useFacts ? _factsUrl : _aiUrl);
    final body = jsonEncode(useFacts ? {'query': prompt} : {'message': prompt});

    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (r.statusCode == 200) {
      final data = jsonDecode(r.body) as Map<String, dynamic>;
      return (data['answer'] ?? data['reply'] ?? '') as String;
    } else {
      throw Exception('AI error ${r.statusCode}: ${r.body}');
    }
  }

  // Stream responses token-by-token with aggregation. Returns a CancelHandle.
  static Future<CancelHandle> streamAskSSE(String prompt, void Function(String chunk) onData, {void Function()? onDone, void Function(Object error)? onError, int flushIntervalMs = 100, int flushThreshold = 40}) async {
    final buffer = StringBuffer();
    Timer? flushTimer;
    bool closed = false;

    void flushBuffer() {
      if (buffer.isEmpty) return;
      final out = buffer.toString();
      buffer.clear();
      try { onData(out); } catch (_) {}
    }

    // Start underlying stream and get a CancelHandle
    final cancelHandle = await streamAskSSE_impl(prompt, (chunk) {
      if (closed) return;
      buffer.write(chunk);
      // If threshold exceeded, flush immediately
      if (buffer.length >= flushThreshold) {
        flushTimer?.cancel();
        flushBuffer();
      } else {
        // Ensure a timer exists to flush periodically
        flushTimer ??= Timer(Duration(milliseconds: flushIntervalMs), () {
          flushBuffer();
          flushTimer = null;
        });
      }
    }, onDone: () {
      // Flush remaining buffer and call onDone
      flushTimer?.cancel();
      flushBuffer();
      closed = true;
      if (onDone != null) onDone();
    }, onError: (e) {
      flushTimer?.cancel();
      closed = true;
      if (onError != null) onError(e);
    });

    // Return a wrapper CancelHandle that flushes then cancels underlying
    return CancelHandle(() {
      if (closed) return;
      flushTimer?.cancel();
      flushBuffer();
      closed = true;
      try {
        (cancelHandle as dynamic).cancel();
      } catch (_) {}
    });
  }
}

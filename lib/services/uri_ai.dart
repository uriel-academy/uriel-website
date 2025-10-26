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
    'minister announced', 'news', '2025', '2026',
    'trivia', 'quiz', 'question', 'answer', 'fact', 'who is', 'what is', 'where is', 'how many'
  ].any((k) => s.contains(k));
}

class UriAI {
  static Future<String> ask(String prompt, {String? imageUrl}) async {
    final useFacts = _needsWeb(prompt);
    final uri = Uri.parse(useFacts ? _factsUrl : _aiUrl);
    final body = jsonEncode(useFacts ? {'query': prompt} : {'message': prompt, if (imageUrl != null) 'image_url': imageUrl});

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
  static Future<CancelHandle> streamAskSSE(String prompt, void Function(String chunk) onData, {void Function()? onDone, void Function(Object error)? onError, int flushIntervalMs = 100, int flushThreshold = 40, String? imageUrl, String? conversationId}) async {
    // Start underlying stream and get a CancelHandle
    final cancelHandle = await streamAskSSE_impl(prompt, (chunk) {
      try { onData(chunk); } catch (_) {}
    }, onDone: () {
      if (onDone != null) onDone();
    }, onError: (e) {
      if (onError != null) onError(e);
    }, imageUrl: imageUrl, conversationId: conversationId);

    // Return the cancel handle directly
    return cancelHandle;
  }
}

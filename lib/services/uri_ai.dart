import 'dart:convert';
import 'package:http/http.dart' as http;

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
}

import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  static const String endpoint =
      'https://us-central1-uriel-academy-41fb0.cloudfunctions.net/aiChat';

  Future<String> send({
    required List<Map<String, String>> messages,
    String? imageUrl,
    Map<String, dynamic>? profile,
    String channel = 'uri_tab',
  }) async {
    final body = jsonEncode({
      'messages': messages,
      'image_url': imageUrl,
      'profile': profile ?? {},
      'channel': channel,
    });

    final resp = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (resp.statusCode != 200) {
      throw Exception('AI error: ${resp.statusCode} ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    return (decoded['reply'] as String?) ?? '';
  }
}

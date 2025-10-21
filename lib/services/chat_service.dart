import 'dart:convert';
import 'uri_ai.dart';
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

  /// Streamed send: calls AI SSE endpoint and invokes onChunk for partial updates.
  Future<CancelHandle?> sendStream({
    required List<Map<String, String>> messages,
    String? imageUrl,
    Map<String, dynamic>? profile,
    String channel = 'uri_tab',
    required void Function(String chunk) onChunk,
    void Function()? onDone,
    void Function(Object error)? onError,
  }) async {
    final prompt = (messages.isNotEmpty ? messages.last['content'] ?? '' : '');
    try {
      final handle = await UriAI.streamAskSSE(prompt, (chunk) {
        onChunk(chunk);
      }, onDone: onDone, onError: onError);
      return handle;
    } catch (e) {
      if (onError != null) onError(e);
      rethrow;
    }
  }
}

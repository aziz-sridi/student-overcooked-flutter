import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AskAiService {
  AskAiService._();

  static final AskAiService instance = AskAiService._();

  static const String _baseUrl = String.fromEnvironment('BACKEND_BASE_URL');

  Future<String> ask({
    required String prompt,
    required String projectId,
    String? projectTitle,
  }) async {
    if (_baseUrl.isEmpty) {
      throw StateError('Backend base URL is not configured.');
    }

    final uri = Uri.parse('$_baseUrl/askai');
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final body = jsonEncode({
      'prompt': prompt,
      'projectId': projectId,
      'projectTitle': projectTitle,
    });

    final response = await http.post(uri, headers: headers, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Ask AI failed (${response.statusCode}).');
    }

    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final answer =
            data['answer'] ??
            data['text'] ??
            data['message'] ??
            data['response'];
        if (answer is String && answer.trim().isNotEmpty) {
          return answer.trim();
        }
      }
      if (data is String && data.trim().isNotEmpty) {
        return data.trim();
      }
    } catch (_) {
      final raw = response.body.trim();
      if (raw.isNotEmpty) {
        return raw;
      }
    }

    throw StateError('Ask AI returned an empty response.');
  }
}

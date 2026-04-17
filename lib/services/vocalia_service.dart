import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/vocalia.dart';
import 'auth_service.dart';

class VocaliaService {
  static const String baseUrl = Environment.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  void _handleError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Server error');
    } catch (_) {
      throw Exception('Server error (${response.statusCode})');
    }
  }

  Future<List<MatchVocalia>> getByMatch(String matchId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/vocalia/match/$matchId'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return [];
      }

      final rawVocalia = decoded['vocalia'];
      if (rawVocalia is! List) {
        return [];
      }

      return rawVocalia
          .whereType<Map<String, dynamic>>()
          .map(MatchVocalia.fromJson)
          .toList();
    }

    _handleError(response);
    return [];
  }
}

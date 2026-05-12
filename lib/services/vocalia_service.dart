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

  Future<VocaliaValue> addValueToMatchTeam({
    required String matchId,
    required String teamId,
    required String concept,
    required double amount,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/vocalia/match/$matchId/team/$teamId/values'),
      headers: await _headers(),
      body: jsonEncode({
        'concept': concept.trim(),
        'amount': amount,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return VocaliaValue.fromJson(decoded);
      }
      throw Exception('Respuesta invalida del servidor');
    }

    _handleError(response);
    throw Exception('Error desconocido');
  }

  Future<VocaliaValue> updateValueInMatchTeam({
    required String matchId,
    required String teamId,
    required String valueId,
    String? concept,
    double? amount,
  }) async {
    final payload = <String, dynamic>{};
    if (concept != null) payload['concept'] = concept.trim();
    if (amount != null) payload['amount'] = amount;

    final response = await http.patch(
      Uri.parse(
        '$baseUrl/vocalia/match/$matchId/team/$teamId/values/$valueId',
      ),
      headers: await _headers(),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return VocaliaValue.fromJson(decoded);
      }
      throw Exception('Respuesta invalida del servidor');
    }

    _handleError(response);
    throw Exception('Error desconocido');
  }

  Future<void> deleteValueInMatchTeam({
    required String matchId,
    required String teamId,
    required String valueId,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '$baseUrl/vocalia/match/$matchId/team/$teamId/values/$valueId',
      ),
      headers: await _headers(),
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      return;
    }

    _handleError(response);
  }
}

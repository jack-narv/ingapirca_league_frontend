import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/match_referee_observation.dart';
import 'auth_service.dart';

class MatchRefereeObservationsService {
  static const String baseUrl = Environment.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  void _handleError(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      throw Exception(body["message"] ?? "Server error");
    } catch (_) {
      throw Exception("Server error (${response.statusCode})");
    }
  }

  Future<MatchRefereeObservation> submitObservation({
    required String matchId,
    required String refereeId,
    required String observation,
    String? status,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/match-referee-observations"),
      headers: await _headers(),
      body: jsonEncode({
        "match_id": matchId,
        "referee_id": refereeId,
        "observation": observation,
        "status": status,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return MatchRefereeObservation.fromJson(
        jsonDecode(response.body),
      );
    }

    _handleError(response);
    throw Exception();
  }

  Future<List<MatchRefereeObservation>> getByMatch(
    String matchId,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/match-referee-observations/match/$matchId"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(MatchRefereeObservation.fromJson)
          .toList();
    }

    _handleError(response);
    return [];
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/match_observations.dart';
import 'auth_service.dart';

class MatchObservationsService {
  static const String baseUrl = Environment.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<List<MatchObservation>> getAll({
    String? matchId,
    String? teamId,
    String? status,
  }) async {
    final Map<String, String> queryParams = {};

    if (matchId != null && matchId.isNotEmpty) {
      queryParams['match_id'] = matchId;
    }
    if (teamId != null && teamId.isNotEmpty) {
      queryParams['team_id'] = teamId;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse("$baseUrl/match-observations").replace(
      queryParameters:
          queryParams.isEmpty ? null : queryParams,
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map((e) => MatchObservation.fromJson(e))
          .toList();
    }

    throw Exception("Error cargando observaciones del partido");
  }

  Future<List<MatchObservation>> getByMatch(
    String matchId,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/match-observations/match/$matchId"),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map((e) => MatchObservation.fromJson(e))
          .toList();
    }

    throw Exception("Error cargando observaciones del partido");
  }

  Future<void> submitObservation({
    required String matchId,
    required String teamId,
    required String submittedBy,
    required String observation,
    String? status,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/match-observations"),
      headers: await _headers(),
      body: jsonEncode({
        "match_id": matchId,
        "team_id": teamId,
        "submitted_by": submittedBy,
        "observation": observation,
        "status": status,
      }),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception("Error guardando observacion");
    }
  }
}

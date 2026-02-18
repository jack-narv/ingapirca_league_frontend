import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/match_lineup.dart';
import 'auth_service.dart';

class MatchLineupsService {
  static const String baseUrl = Environment.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<List<MatchLineupPlayer>> getLineup(
      String matchId, String teamId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/match-lineups/$matchId/team/$teamId"),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map((e) => MatchLineupPlayer.fromJson(e))
          .toList();
    } else {
      throw Exception("Error cargando la alineación");
    }
  }

  Future<void> submitLineup({
    required String matchId,
    required String teamId,
    required List<MatchLineupPlayer> players,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/match-lineups"),
      headers: await _headers(),
      body: jsonEncode({
        "match_id": matchId,
        "team_id": teamId,
        "players": players.map((e) => e.toSubmitJson()).toList(),
      }),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception("Error subiendo la alineación");
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/match.dart';
import '../models/match_observations.dart';
import 'auth_service.dart';
import 'match_observations_service.dart';
import 'package:ingapirca_league_frontend/core/constants/environments.dart';

class MatchesService {
  static const String baseUrl = Environment.baseUrl;
  final AuthService _auth = AuthService();
  final MatchObservationsService _matchObservationsService =
      MatchObservationsService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ============================
  // GET MATCHES BY SEASON
  // ============================

  Future<List<Match>> getBySeason(
    String seasonId, {
    String? categoryId,
  }) async {
    final query = categoryId == null
        ? ''
        : '?categoryId=$categoryId';
    final res = await http.get(
      Uri.parse("$baseUrl/matches/season/$seasonId$query"),
    );

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Match.fromJson(e)).toList();
    }

    throw Exception("Error cargando partidos");
  }

  Future<Match> getMatch(String matchId) async {
    final res = await http.get(
      Uri.parse("$baseUrl/matches/$matchId"),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return Match.fromJson(data);
    }

    throw Exception("Error cargando partido");
  }

  // ============================
  // CREATE MATCH
  // ============================

  Future<void> createMatch({
    required String seasonId,
    String? categoryId,
    required String homeTeamId,
    required String awayTeamId,
    required String venueId,
    required DateTime matchDate,
    String? observations,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/matches"),
      headers: await _headers(),
      body: jsonEncode({
        "season_id": seasonId,
        "category_id": categoryId,
        "home_team_id": homeTeamId,
        "away_team_id": awayTeamId,
        "venue_id": venueId,
        "match_date": matchDate.toIso8601String(),
        "observations": observations,
      }),
    );

    if (res.statusCode != 200 &&
        res.statusCode != 201) {
      throw Exception("Error creando partido");
    }
  }

  // ============================
  // START MATCH
  // ============================

  Future<void> startMatch(String matchId) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/matches/$matchId/start"),
      headers: await _headers(),
    );

    if (res.statusCode != 200) {
      throw Exception("Error al iniciar el partido");
    }
  }

  // ============================
  // FINISH MATCH
  // ============================

  Future<void> finishMatch(
    String matchId,
    int homeScore,
    int awayScore,
    String? observations,
  ) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/matches/$matchId/finish"),
      headers: await _headers(),
      body: jsonEncode({
        "home_score": homeScore,
        "away_score": awayScore,
        "observations": observations,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Error finalizando el partido");
    }
  }

  // ============================
  // CANCEL MATCH
  // ============================

  Future<void> cancelMatch(
    String matchId,
    String? observations,
  ) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/matches/$matchId/cancel"),
      headers: await _headers(),
      body: jsonEncode({
        "observations": observations,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception("Error cancelando el partido");
    }
  }

  // ============================
  // MATCH OBSERVATIONS (TEAM)
  // ============================

  Future<List<MatchObservation>> getTeamObservationsByMatch(
    String matchId,
  ) {
    return _matchObservationsService.getByMatch(matchId);
  }

  Future<List<MatchObservation>> getTeamObservations({
    String? matchId,
    String? teamId,
    String? status,
  }) {
    return _matchObservationsService.getAll(
      matchId: matchId,
      teamId: teamId,
      status: status,
    );
  }

  Future<void> submitTeamObservation({
    required String matchId,
    required String teamId,
    required String submittedBy,
    required String observation,
    String? status,
  }) {
    return _matchObservationsService.submitObservation(
      matchId: matchId,
      teamId: teamId,
      submittedBy: submittedBy,
      observation: observation,
      status: status,
    );
  }
}

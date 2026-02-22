import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/match.dart';
import '../models/match_observations.dart';
import 'auth_service.dart';
import 'match_observations_service.dart';
import 'package:ingapirca_league_frontend/core/constants/environments.dart';
import 'package:ingapirca_league_frontend/core/utils/ecuador_time.dart';

class MatchRefereeAssignmentInput {
  final String refereeId;
  final String role;

  MatchRefereeAssignmentInput({
    required this.refereeId,
    required this.role,
  });
}

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

  String _extractErrorMessage(http.Response res, String fallback) {
    try {
      final decoded = jsonDecode(res.body);

      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }

        if (message is List && message.isNotEmpty) {
          return message.map((e) => e.toString()).join(', ');
        }
      }
    } catch (_) {}

    return fallback;
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

  Future<String?> createMatch({
    required String seasonId,
    String? categoryId,
    required String journal,
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
        "journal": journal,
        "home_team_id": homeTeamId,
        "away_team_id": awayTeamId,
        "venue_id": venueId,
        "match_date": EcuadorTime.ecuadorLocalToUtcIso(matchDate),
        "observations": observations,
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        _extractErrorMessage(res, "Error creando partido"),
      );
    }

    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        final directId =
            (decoded['id'] ?? decoded['_id'])?.toString();
        if (directId != null && directId.isNotEmpty) {
          return directId;
        }

        final nested = decoded['match'];
        if (nested is Map<String, dynamic>) {
          return (nested['id'] ?? nested['_id'])?.toString();
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> addRefereeToMatch({
    required String matchId,
    required String refereeId,
    required String role,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/referees/assign"),
      headers: await _headers(),
      body: jsonEncode({
      "match_id": matchId,
      "referee_id": refereeId,
      "role": role,
      }),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(
        _extractErrorMessage(
          res,
          "Error asignando arbitro al partido (${res.statusCode})",
        ),
      );
    }
  }

  Future<void> addRefereesToMatch({
    required String matchId,
    required List<MatchRefereeAssignmentInput> assignments,
  }) async {
    for (final assignment in assignments) {
      await addRefereeToMatch(
        matchId: matchId,
        refereeId: assignment.refereeId,
        role: assignment.role,
      );
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
      throw Exception(
        _extractErrorMessage(res, "Error al iniciar el partido"),
      );
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
    String? bestPlayerId,
    String? bestGoalkeeperId,
  ) async {
    final res = await http.patch(
      Uri.parse("$baseUrl/matches/$matchId/finish"),
      headers: await _headers(),
      body: jsonEncode({
        "home_score": homeScore,
        "away_score": awayScore,
        "observations": observations,
        "best_player_id": bestPlayerId,
        "best_goalkeeper_id": bestGoalkeeperId,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception(
        _extractErrorMessage(res, "Error finalizando el partido"),
      );
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
      throw Exception(
        _extractErrorMessage(res, "Error cancelando el partido"),
      );
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

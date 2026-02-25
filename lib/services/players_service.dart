import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/player.dart';
import '../models/team_player.dart';
import 'auth_service.dart';
import 'package:ingapirca_league_frontend/core/constants/environments.dart';
import 'package:ingapirca_league_frontend/core/utils/ecuador_time.dart';

class PlayersService {
  static const String baseUrl = Environment.baseUrl;
  final AuthService _authService = AuthService();

  // ============================
  // HEADERS
  // ============================

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

  // ============================
  // GET ALL PLAYERS
  // ============================

  Future<List<Player>> getAllPlayers() async {
    final response = await http.get(
      Uri.parse("$baseUrl/players"),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Player.fromJson(e)).toList();
    }

    _handleError(response);
    return [];
  }

  // ============================
  // GET PLAYER DETAILS
  // ============================

  Future<Player> getPlayer(String id) async {
    final response = await http.get(
      Uri.parse("$baseUrl/players/$id"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return Player.fromJson(jsonDecode(response.body));
    }

    _handleError(response);
    throw Exception();
  }

  // ============================
  // CREATE PLAYER (ADMIN)
  // ============================

  Future<Player> createPlayer({
    required String firstName,
    required String lastName,
    required String nationality,
    required DateTime birthDate,
    required String identityCard,
    String? photoUrl,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/players"),
      headers: await _headers(),
      body: jsonEncode({
        "first_name": firstName,
        "last_name": lastName,
        "date_of_birth": EcuadorTime.dateOnlyIso(birthDate),
        "nationality": nationality,
        "identity_card": identityCard,
        "photo_url": photoUrl,
      }),
    );

    if (response.statusCode == 201 ||
        response.statusCode == 200) {
      return Player.fromJson(jsonDecode(response.body));
    }

    _handleError(response);
    throw Exception();
  }


  // ============================
  // ASSIGN PLAYER TO TEAM
  // ============================

  Future<void> assignPlayer({
    required String playerId,
    required String teamId,
    required int shirtNumber,
    required String position,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/players/assign"),
      headers: await _headers(),
      body: jsonEncode({
        "player_id": playerId,
        "team_id": teamId,
        "shirt_number": shirtNumber,
        "position": position,
      }),
    );

    if (response.statusCode != 201 &&
        response.statusCode != 200) {
      _handleError(response);
    }
  }

  // ============================
  // RELEASE PLAYER
  // ============================

  Future<void> releasePlayer(String teamPlayerId) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/players/release/$teamPlayerId"),
      headers: await _headers(),
    );

    if (response.statusCode != 200) {
      _handleError(response);
    }
  }

  // ============================
  // GET PLAYERS BY TEAM
  // ============================

  Future<List<TeamPlayer>> getByTeam(String teamId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/players/team/$teamId"),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map((e) => TeamPlayer.fromJson(e))
          .toList();
    }

    _handleError(response);
    return [];
  }
}

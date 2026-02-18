import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/match_event.dart';
import 'auth_service.dart';

class MatchEventsService {
  static const String baseUrl = Environment.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<List<MatchEvent>> getTimeline(String matchId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/match-events/match/$matchId"),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => MatchEvent.fromJson(e)).toList();
    } else {
      throw Exception("Error cargando línea temporal");
    }
  }

  Future<void> createEvent({
    required String matchId,
    required String teamId,
    required String playerId,
    required int minute,
    required String eventType,
    String? relatedPlayerId,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/match-events"),
      headers: await _headers(),
      body: jsonEncode({
        "match_id": matchId,
        "team_id": teamId,
        "player_id": playerId,
        "minute": minute,
        "event_type": eventType,
        "related_player_id": relatedPlayerId,
      }),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception("Error creando evento");
    }
  }
}

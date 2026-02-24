import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/player_statistics.dart';

class PlayerStatisticsService {
  static const String baseUrl = Environment.baseUrl;

  Future<List<PlayerStatistics>> getBySeason(
    String seasonId, {
    String? categoryId,
  }) async {
    final query = categoryId == null ? '' : '?categoryId=$categoryId';
    final response = await http.get(
      Uri.parse("$baseUrl/player-statistics/season/$seasonId$query"),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(PlayerStatistics.fromJson)
          .toList();
    }

    throw Exception("Error cargando estadisticas por temporada");
  }

  Future<PlayerStatistics> getByPlayerSeason(
    String playerId,
    String seasonId,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/player-statistics/player/$playerId?seasonId=$seasonId"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return PlayerStatistics.fromJson(data);
      }
    }

    throw Exception("Error cargando estadisticas del jugador en temporada");
  }

  Future<List<PlayerStatistics>> getByPlayer(String playerId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/player-statistics/player/$playerId"),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(PlayerStatistics.fromJson)
          .toList();
    }

    throw Exception("Error cargando historial de estadisticas del jugador");
  }

  Future<List<PlayerStatistics>> getTopScorers(
    String seasonId, {
    int limit = 10,
    String? categoryId,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      ...?(categoryId == null ? null : {'categoryId': categoryId}),
    };

    final uri = Uri.parse("$baseUrl/player-statistics/season/$seasonId/top-scorers")
        .replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(PlayerStatistics.fromJson)
          .toList();
    }

    throw Exception("Error cargando top goleadores");
  }

  Future<List<PlayerStatistics>> getTopCards(
    String seasonId, {
    int limit = 10,
    String? categoryId,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      ...?(categoryId == null ? null : {'categoryId': categoryId}),
    };

    final uri = Uri.parse("$baseUrl/player-statistics/season/$seasonId/top-cards")
        .replace(queryParameters: params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(PlayerStatistics.fromJson)
          .toList();
    }

    throw Exception("Error cargando top tarjetas");
  }
}

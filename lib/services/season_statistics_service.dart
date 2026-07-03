import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/environments.dart';
import '../models/season_scorer_summary.dart';

class SeasonStatisticsService {
  static const String baseUrl = Environment.baseUrl;

  Future<List<SeasonScorerCategory>> getScorersSummary(
    String seasonId, {
    String? categoryId,
  }) async {
    final params = <String, String>{
      ...?(categoryId == null ? null : {'categoryId': categoryId}),
    };

    final uri = Uri.parse("$baseUrl/player-statistics/season/$seasonId/scorers-summary")
        .replace(queryParameters: params.isEmpty ? null : params);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(SeasonScorerCategory.fromJson)
          .toList();
    }

    throw Exception("Error cargando resumen de goleadores");
  }
}

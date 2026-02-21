import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/referee_ratings.dart';
import 'auth_service.dart';

class RefereeRatingsService {
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

  Future<RefereeRating> create({
    required String matchId,
    required String refereeId,
    required String teamId,
    required int rating,
    String? comment,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/referee-ratings"),
      headers: await _headers(),
      body: jsonEncode({
        "match_id": matchId,
        "referee_id": refereeId,
        "team_id": teamId,
        "rating": rating,
        "comment": comment,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return RefereeRating.fromJson(jsonDecode(response.body));
    }

    _handleError(response);
    throw Exception();
  }

  Future<List<RefereeRating>> getByMatch(String matchId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/referee-ratings/match/$matchId"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(RefereeRating.fromJson)
          .toList();
    }

    _handleError(response);
    return [];
  }

  Future<List<RefereeRating>> getAll({
    String? matchId,
    String? refereeId,
    String? teamId,
    String? seasonId,
  }) async {
    final queryParams = <String, String>{};
    if (matchId != null && matchId.isNotEmpty) {
      queryParams['match_id'] = matchId;
    }
    if (refereeId != null && refereeId.isNotEmpty) {
      queryParams['referee_id'] = refereeId;
    }
    if (teamId != null && teamId.isNotEmpty) {
      queryParams['team_id'] = teamId;
    }
    if (seasonId != null && seasonId.isNotEmpty) {
      queryParams['season_id'] = seasonId;
    }

    final uri = Uri.parse("$baseUrl/referee-ratings")
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(RefereeRating.fromJson)
          .toList();
    }

    _handleError(response);
    return [];
  }

  Future<RefereeAverageRating> getAverageByReferee(
    String refereeId,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/referee-ratings/referee/$refereeId/average"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      return RefereeAverageRating.fromJson(
        jsonDecode(response.body),
      );
    }

    _handleError(response);
    throw Exception();
  }
}

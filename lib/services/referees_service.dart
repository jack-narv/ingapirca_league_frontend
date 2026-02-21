import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/referees.dart';
import 'auth_service.dart';

class RefereesService {
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

  Future<List<Referee>> getBySeason(String seasonId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/referees/season/$seasonId"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(Referee.fromJson)
          .toList();
    }

    _handleError(response);
    return [];
  }

  Future<Referee> createReferee({
    required String seasonId,
    required String firstName,
    required String lastName,
    required String licenseNumber,
    String? phone,
    bool isActive = true,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/referees"),
      headers: await _headers(),
      body: jsonEncode({
        "season_id": seasonId,
        "first_name": firstName,
        "last_name": lastName,
        "license_number": licenseNumber,
        "phone": phone,
        "is_active": isActive,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Referee.fromJson(jsonDecode(response.body));
    }

    _handleError(response);
    throw Exception();
  }

  Future<List<MatchRefereeAssignment>> getByMatch(
    String matchId,
  ) async {
    final response = await http.get(
      Uri.parse("$baseUrl/referees/match/$matchId"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .whereType<Map<String, dynamic>>()
          .map(MatchRefereeAssignment.fromJson)
          .toList();
    }

    _handleError(response);
    return [];
  }
}

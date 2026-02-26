import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/cards_summary.dart';
import '../models/suspended_player.dart';
import '../models/suspension_summary.dart';
import 'auth_service.dart';

class SanctionsService {
  static const String baseUrl = Environment.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
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

  Future<List<SuspendedPlayer>> getSuspendedPlayers({
    required String matchId,
    required String teamId,
  }) async {
    final response = await http.get(
      Uri.parse("$baseUrl/sanctions/suspended-players/$matchId/team/$teamId"),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => SuspendedPlayer.fromJson(e)).toList();
    }

    throw Exception(
      _extractErrorMessage(response, "Error cargando jugadores suspendidos"),
    );
  }

  Future<List<SuspensionSummary>> getSuspensionsSummaryBySeason({
    required String seasonId,
    String? categoryId,
    String? teamId,
  }) async {
    final query = <String, String>{};
    if (categoryId != null && categoryId.isNotEmpty) {
      query['categoryId'] = categoryId;
    }
    if (teamId != null && teamId.isNotEmpty) {
      query['teamId'] = teamId;
    }

    final uri = Uri.parse(
      "$baseUrl/sanctions/suspensions-summary/season/$seasonId",
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => SuspensionSummary.fromJson(e)).toList();
    }

    throw Exception(
      _extractErrorMessage(response, "Error cargando resumen de suspensiones"),
    );
  }

  Future<List<CardsSummary>> getCardsSummaryBySeason({
    required String seasonId,
    String? categoryId,
    String? teamId,
  }) async {
    final query = <String, String>{};
    if (categoryId != null && categoryId.isNotEmpty) {
      query['categoryId'] = categoryId;
    }
    if (teamId != null && teamId.isNotEmpty) {
      query['teamId'] = teamId;
    }

    final uri = Uri.parse(
      "$baseUrl/sanctions/cards-summary/season/$seasonId",
    ).replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => CardsSummary.fromJson(e)).toList();
    }

    throw Exception(
      _extractErrorMessage(response, "Error cargando resumen de tarjetas"),
    );
  }
}

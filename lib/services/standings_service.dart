import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/standings.dart';
import 'auth_service.dart';

class StandingsService {
  static const String baseUrl = Environment.baseUrl;

  Future<List<Standing>> getBySeason(
    String seasonId, {
    String? categoryId,
  }) async {
    final query = categoryId == null ? '' : '?categoryId=$categoryId';
    final response = await http.get(
      Uri.parse("$baseUrl/standings/season/$seasonId$query"),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => Standing.fromJson(e)).toList();
    }

    throw Exception("Error cargando clasificacion");
  }

  Future<void> recalculateSeason(
    String seasonId, {
    String? categoryId,
  }) async {
    final token = await AuthService().getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception("Sesion expirada. Vuelve a iniciar sesion.");
    }

    final query = categoryId == null ? '' : '?categoryId=$categoryId';
    final response = await http.post(
      Uri.parse("$baseUrl/standings/season/$seasonId/recalculate$query"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    }

    var message = "Error al actualizar la clasificacion";
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded["message"] != null) {
        final serverMessage = decoded["message"];
        if (serverMessage is List && serverMessage.isNotEmpty) {
          message = serverMessage.first.toString();
        } else {
          message = serverMessage.toString();
        }
      }
    } catch (_) {
      // Keep fallback message.
    }
    throw Exception(message);
  }
}

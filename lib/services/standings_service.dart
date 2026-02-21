import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/environments.dart';
import '../models/standings.dart';

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
}

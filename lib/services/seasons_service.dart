import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/season.dart';
import '../models/season_category.dart';
import 'package:ingapirca_league_frontend/core/constants/environments.dart';


class SeasonsService {
  static const String baseUrl = Environment.baseUrl;
  final _storage = const FlutterSecureStorage();

  Future<List<Season>> getByLeague(String leagueId) async{
    final response = await http.get(
      Uri.parse("$baseUrl/seasons/league/$leagueId"),
    );

    if(response.statusCode == 200){
      final List data = jsonDecode(response.body);
      return data.map((e)=>Season.fromJson(e)).toList();
    }else{
      throw Exception("No se pudo cargar las temporadas");
    }
  }

  Future<Season> createSeason({
    required String leagueId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async{
    final token = await _storage.read(key: "jwt");

    final response = await http.post(
      Uri.parse("$baseUrl/seasons"),
      headers:{
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "league_id": leagueId,
        "name": name,
        "start_date": startDate.toIso8601String(),
        "end_date": endDate.toIso8601String(),
      }),
    );

    if(response.statusCode != 201 &&
        response.statusCode != 200){
      throw Exception("No se pudo crear la temporada");
    }

    final data = jsonDecode(response.body);
    return Season.fromJson(data);
  }

  Future<List<SeasonCategory>> getCategoriesBySeason(
      String seasonId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/seasons/$seasonId/categories"),
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data
          .map((e) => SeasonCategory.fromJson(e))
          .toList();
    }

    throw Exception("No se pudo cargar categorias");
  }

  Future<void> createCategory({
    required String seasonId,
    required String name,
    int? sortOrder,
  }) async {
    final token = await _storage.read(key: "jwt");

    final response = await http.post(
      Uri.parse("$baseUrl/season-categories"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "season_id": seasonId,
        "name": name,
        "sort_order": sortOrder,
      }),
    );

    if (response.statusCode != 201 &&
        response.statusCode != 200) {
      throw Exception("No se pudo crear la categoria");
    }
  }
}

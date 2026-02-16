import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/season.dart';
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

  Future<void> createSeason({
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

    if(response.statusCode != 201){
      throw Exception("No se pudo crear la temporada");
    }
  }
}
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/team.dart';
import 'auth_service.dart';
import 'package:ingapirca_league_frontend/core/constants/environments.dart';


class TeamsService{
  static const String baseUrl = Environment.baseUrl;

  Future<List<Team>> getBySeason(String seasonId) async{
    final response = await http.get(
      Uri.parse("$baseUrl/teams/season/$seasonId"),
    );

    if(response.statusCode == 200){
      final List data = jsonDecode(response.body);
      return data.map((e)=> Team.fromJson(e)).toList();
    }else{
      throw Exception("Error cargando los equipos");
    }
  }

  Future<void> createTeam({
    required String seasonId,
    required String name,
    int? foundedYear,
    String? logoUrl,
  }) async{
    final token = await AuthService().getToken();

    final response = await http.post(
      Uri.parse("$baseUrl/teams"),
      headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "season_id": seasonId,
        "name": name,
        "founded_year": foundedYear,
        "logo_url": logoUrl,
      }),
    );

    if(response.statusCode != 201 &&
       response.statusCode != 200){
        throw Exception("Error al crear el equipo.");
    }
  }
}
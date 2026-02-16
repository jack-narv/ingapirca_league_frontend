import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/league.dart';
import 'package:ingapirca_league_frontend/core/constants/environments.dart';


class LeaguesService {
  static const String baseUrl = Environment.baseUrl;
  final _storage = const FlutterSecureStorage();

  Future<List<League>> getLeagues() async {
    final response = await http.get(
      Uri.parse("$baseUrl/leagues"),
    );

    if(response.statusCode == 200){
      final List data = jsonDecode(response.body);
      return data.map((e)=> League.fromJson(e)).toList();
    }else{
      throw Exception("No se pudo cargar las ligas");
    }
  }

  Future<void> createLeague(
    String name, String country, String city) async{
      final token = await _storage.read(key: "jwt");

      final response = await http.post(
        Uri.parse("$baseUrl/leagues"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "name": name,
          "country": country,
          "city": city,
        }),
      );

      if(response.statusCode != 201){
        throw Exception("No se pudo crear la liga");
      }
    }
}
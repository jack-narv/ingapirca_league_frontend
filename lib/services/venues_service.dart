import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/venue.dart';
import '../services/auth_service.dart';
import '../core/constants/environments.dart';

class VenuesService{
  static const String baseUrl = Environment.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();

    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  //Get All
  Future<List<Venue>> getAll() async{
    final response = await http.get(
      Uri.parse("$baseUrl/venues"),
    );

    if(response.statusCode == 200){
      final List data = jsonDecode(response.body);
      return data.map((e)=> Venue.fromJson(e)).toList();
    }else{
      throw Exception("Error obteniendo eventos");
    }
  }

  //Create
  Future<void> create({
    required String name,
    String? address,
  }) async{
    final response = await http.post(
      Uri.parse("$baseUrl/venues"),
      headers: await _headers(),
      body: jsonEncode({
        "name": name,
        "address": address,
      }),
    );

    if(response.statusCode != 201 &&
       response.statusCode != 200){
        throw Exception("Error al crear el evento");
      }
  }

  //Update
  Future<void> update({
    required String id,
    String? name,
    String? address,
  }) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/venues/$id"),
      headers: await _headers(),
      body: jsonEncode({
        "name": name,
        "address": address,
      }),
    );

    if(response.statusCode != 200){
      throw Exception("Error actualizando el evento");
    }
  }
}
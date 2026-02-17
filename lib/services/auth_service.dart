import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_response.dart';
import 'package:ingapirca_league_frontend/core/constants/environments.dart';


class AuthService {
  static const String baseUrl = Environment.baseUrl; 
  // IMPORTANT:
  // For Android Emulator use 10.0.2.2
  // For physical phone use your PC local IP like:
  // http://192.168.1.10:3000

  final _storage = const FlutterSecureStorage();

  Future<AuthResponse> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final auth = AuthResponse.fromJson(data);

      await _storage.write(key: "jwt", value: auth.accessToken);
      await _storage.write(
        key: "roles",
        value: auth.roles.join(','),
      );
      return auth;
    } else {
      throw Exception("Login failed");
    }
  }

  Future<void> register(
    String email,
    String password,
    String fullName,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        "fullName": fullName,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      // After register → login automatically
      await login(email, password);
    } else {
      throw Exception("Register failed: ${response.body}");
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: "jwt");
  }

  Future<void> logout() async {
    await _storage.delete(key: "jwt");
  }

  Future<bool> isAdmin() async {
    final roles = await _storage.read(key: "roles");
    if (roles == null) return false;
    return roles.split(',').contains("ADMIN");
  }

  Future<bool> canManageTeams() async {
    final roles = await _storage.read(key: "roles");
    if (roles == null) return false;
    return roles.contains('ADMIN') ||
          roles.contains('LEAGUE_ADMIN');
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_response.dart';
import 'package:ingapirca_league_frontend/core/constants/environments.dart';


class AuthService {
  static const String baseUrl = Environment.baseUrl; 
  static const String _jwtKey = "jwt";
  static const String _rolesKey = "roles";
  static const String _refreshTokenKey = "refresh_token";
  static Future<bool>? _refreshInFlight;
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
      final resolvedRoles = _resolveRolesForStorage(
        auth.roles,
        auth.accessToken,
      );

      await _storage.write(key: _jwtKey, value: auth.accessToken);
      await _storage.write(
        key: _rolesKey,
        value: resolvedRoles.join(','),
      );
      if (auth.refreshToken != null && auth.refreshToken!.isNotEmpty) {
        await _storage.write(
          key: _refreshTokenKey,
          value: auth.refreshToken!,
        );
      }
      return auth;
    } else {
      String message = "Credenciales inválidas";
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
        // Keep fallback message if response body is not JSON.
      }
      throw Exception(message);
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

  Future<void> deleteAccount() async {
    final token = await getToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception("No hay sesion activa");
    }

    final response = await http.delete(
      Uri.parse("$baseUrl/auth/account"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      String message = "No se pudo eliminar la cuenta";
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded["message"] != null) {
          message = decoded["message"].toString();
        }
      } catch (_) {
        // keep default message
      }
      throw Exception(message);
    }
  }

  Future<String?> getToken() async {
    final token = await _storage.read(key: _jwtKey);
    if (_isTokenValid(token)) {
      return token;
    }

    final refreshed = await _refreshSession();
    if (!refreshed) {
      return null;
    }

    final updatedToken = await _storage.read(key: _jwtKey);
    if (_isTokenValid(updatedToken)) {
      return updatedToken;
    }
    return null;
  }

  Future<bool> hasValidSession() async {
    final token = await getToken();
    return token != null && token.trim().isNotEmpty;
  }

  Future<bool> _refreshSession() async {
    final current = _refreshInFlight;
    if (current != null) {
      return current;
    }

    final future = _refreshSessionInternal();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _refreshSessionInternal() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      await logout();
      return false;
    }
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/refresh"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "refreshToken": refreshToken,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        await logout();
        return false;
      }

      final data = jsonDecode(response.body);
      final auth = AuthResponse.fromJson(data);
      final resolvedRoles = _resolveRolesForStorage(
        auth.roles,
        auth.accessToken,
      );
      if (auth.accessToken.isEmpty) {
        await logout();
        return false;
      }

      await _storage.write(key: _jwtKey, value: auth.accessToken);
      await _storage.write(key: _rolesKey, value: resolvedRoles.join(','));
      if (auth.refreshToken != null && auth.refreshToken!.isNotEmpty) {
        await _storage.write(key: _refreshTokenKey, value: auth.refreshToken!);
      }

      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  bool _isTokenValid(String? token) {
    if (token == null || token.trim().isEmpty) {
      return false;
    }

    final payload = _decodeJwtPayload(token);
    if (payload == null) {
      return false;
    }

    final exp = payload['exp'];
    if (exp is! num) {
      return false;
    }

    final expiryUtc =
        DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);

    // Refresh proactively if token expires in <= 30 seconds.
    return expiryUtc.isAfter(DateTime.now().toUtc().add(const Duration(seconds: 30)));
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _rolesKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<Set<String>> _getRoleSet() async {
    final fromStorage = <String>{};
    final rawRoles = await _storage.read(key: _rolesKey);
    if (rawRoles != null && rawRoles.trim().isNotEmpty) {
      fromStorage.addAll(
        rawRoles
            .split(',')
            .map((role) => role.trim().toUpperCase())
            .where((role) => role.isNotEmpty),
      );
    }

    // Fallback: derive roles from JWT payload if secure-storage role key is stale/missing.
    final fromToken = <String>{};
    final token = await _storage.read(key: _jwtKey);
    final payload = _decodeJwtPayload(token ?? '');
    final payloadRoles = payload?['roles'];
    if (payloadRoles is List) {
      fromToken.addAll(
        payloadRoles
            .map((role) => role.toString().trim().toUpperCase())
            .where((role) => role.isNotEmpty),
      );
    } else if (payloadRoles is String && payloadRoles.trim().isNotEmpty) {
      fromToken.addAll(
        payloadRoles
            .split(',')
            .map((role) => role.trim().toUpperCase())
            .where((role) => role.isNotEmpty),
      );
    }

    return {
      ...fromStorage,
      ...fromToken,
    };
  }

  List<String> _resolveRolesForStorage(
    List<String> responseRoles,
    String accessToken,
  ) {
    final normalizedResponse = responseRoles
        .map((r) => r.trim().toUpperCase())
        .where((r) => r.isNotEmpty)
        .toSet();

    if (normalizedResponse.isNotEmpty) {
      return normalizedResponse.toList();
    }

    final payload = _decodeJwtPayload(accessToken);
    final payloadRoles = payload?['roles'];
    final fromToken = <String>{};

    if (payloadRoles is List) {
      fromToken.addAll(
        payloadRoles
            .map((r) => r.toString().trim().toUpperCase())
            .where((r) => r.isNotEmpty),
      );
    } else if (payloadRoles is String && payloadRoles.trim().isNotEmpty) {
      fromToken.addAll(
        payloadRoles
            .split(',')
            .map((r) => r.trim().toUpperCase())
            .where((r) => r.isNotEmpty),
      );
    }

    return fromToken.toList();
  }

  Future<bool> isAdmin() async {
    final roles = await _getRoleSet();
    return roles.contains("ADMIN");
  }

  Future<bool> canManageTeams() async {
    final roles = await _getRoleSet();
    return roles.contains('ADMIN') || roles.contains('LEAGUE_ADMIN');
  }

  Future<bool> canManageSeasons() async {
    final roles = await _getRoleSet();
    return roles.contains('ADMIN');
  }

  Future<bool> canManageMatchFlow() async {
    final roles = await _getRoleSet();
    return roles.contains('ADMIN') ||
        roles.contains('LEAGUE_ADMIN') ||
        roles.contains('VOCAL');
  }
}

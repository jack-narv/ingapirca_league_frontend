class AuthResponse {
  final String accessToken;
  final String? refreshToken;
  final List<String> roles;

  AuthResponse({
    required this.accessToken,
    this.refreshToken,
    required this.roles,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final dynamic rawRoles = user is Map
        ? user['roles']
        : json['roles'];

    final roles = <String>[];
    if (rawRoles is List) {
      roles.addAll(rawRoles.map((e) => e.toString()));
    } else if (rawRoles is String && rawRoles.trim().isNotEmpty) {
      roles.addAll(
        rawRoles
            .split(',')
            .map((r) => r.trim())
            .where((r) => r.isNotEmpty),
      );
    }

    return AuthResponse(
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: json['refreshToken']?.toString(),
      roles: roles,
    );
  }
}

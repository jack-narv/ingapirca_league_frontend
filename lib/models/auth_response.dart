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
    return AuthResponse(
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: json['refreshToken']?.toString(),
      roles: List<String>.from(json['user']['roles']),
    );
  }
}

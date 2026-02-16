class AuthResponse {
  final String accessToken;
  final List<String> roles;

  AuthResponse({
    required this.accessToken,
    required this.roles,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'],
      roles: List<String>.from(json['user']['roles']),
    );
  }
}

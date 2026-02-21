class Referee {
  final String id;
  final String seasonId;
  final String firstName;
  final String lastName;
  final String licenseNumber;
  final String? phone;
  final bool isActive;
  final DateTime? createdAt;

  Referee({
    required this.id,
    required this.seasonId,
    required this.firstName,
    required this.lastName,
    required this.licenseNumber,
    this.phone,
    required this.isActive,
    this.createdAt,
  });

  String get fullName => "$firstName $lastName".trim();

  factory Referee.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at'] ?? json['createdAt'];

    return Referee(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      seasonId: (json['season_id'] ?? json['seasonId'] ?? '').toString(),
      firstName: (json['first_name'] ?? json['firstName'] ?? '').toString(),
      lastName: (json['last_name'] ?? json['lastName'] ?? '').toString(),
      licenseNumber:
          (json['license_number'] ?? json['licenseNumber'] ?? '').toString(),
      phone: json['phone']?.toString(),
      isActive: json['is_active'] == null
          ? true
          : (json['is_active'] is bool
              ? json['is_active'] as bool
              : json['is_active'].toString().toLowerCase() == 'true'),
      createdAt: createdAtRaw == null
          ? null
          : DateTime.tryParse(createdAtRaw.toString()),
    );
  }
}

class MatchRefereeAssignment {
  final String id;
  final String matchId;
  final String refereeId;
  final String role;
  final String? observation;
  final DateTime? submittedAt;
  final Referee? referee;

  MatchRefereeAssignment({
    required this.id,
    required this.matchId,
    required this.refereeId,
    required this.role,
    this.observation,
    this.submittedAt,
    this.referee,
  });

  factory MatchRefereeAssignment.fromJson(Map<String, dynamic> json) {
    final submittedAtRaw =
        json['submitted_at'] ?? json['submittedAt'];
    final refereeMap = json['referees'];

    return MatchRefereeAssignment(
      id: (json['id'] ?? '').toString(),
      matchId: (json['match_id'] ?? '').toString(),
      refereeId: (json['referee_id'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      observation: json['observation']?.toString(),
      submittedAt: submittedAtRaw == null
          ? null
          : DateTime.tryParse(submittedAtRaw.toString()),
      referee: refereeMap is Map<String, dynamic>
          ? Referee.fromJson(refereeMap)
          : null,
    );
  }
}

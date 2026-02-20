class MatchObservation {
  final String id;
  final String matchId;
  final String teamId;
  final String submittedBy;
  final String observation;
  final DateTime submittedAt;
  final String status;
  final String? teamName;
  final String? submittedByName;

  MatchObservation({
    required this.id,
    required this.matchId,
    required this.teamId,
    required this.submittedBy,
    required this.observation,
    required this.submittedAt,
    required this.status,
    this.teamName,
    this.submittedByName,
  });

  factory MatchObservation.fromJson(Map<String, dynamic> json) {
    final team = json['teams'];
    final player = json['players'];
    final String firstName = player?['first_name'] ?? '';
    final String lastName = player?['last_name'] ?? '';
    final String fullName = '$firstName $lastName'.trim();

    return MatchObservation(
      id: json['id'],
      matchId: json['match_id'],
      teamId: json['team_id'],
      submittedBy: json['submitted_by'],
      observation: json['observation'],
      submittedAt: DateTime.parse(json['submitted_at']),
      status: json['status'],
      teamName: team?['name'],
      submittedByName: fullName.isEmpty ? null : fullName,
    );
  }
}

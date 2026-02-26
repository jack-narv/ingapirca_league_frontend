class SuspensionSummary {
  final String playerId;
  final String firstName;
  final String lastName;
  final int? shirtNumber;
  final int pendingMatchesSuspended;

  SuspensionSummary({
    required this.playerId,
    required this.firstName,
    required this.lastName,
    required this.shirtNumber,
    required this.pendingMatchesSuspended,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory SuspensionSummary.fromJson(Map<String, dynamic> json) {
    return SuspensionSummary(
      playerId: (json['player_id'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      shirtNumber: json['shirt_number'] == null
          ? null
          : int.tryParse(json['shirt_number'].toString()),
      pendingMatchesSuspended: int.tryParse(
            (
              json['pending_matches_suspended'] ??
              json['total_matches_suspended'] ??
              0
            ).toString(),
          ) ??
          0,
    );
  }
}

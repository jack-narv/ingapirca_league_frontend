class SuspendedPlayer {
  final String playerId;
  final String firstName;
  final String lastName;
  final int pendingMatches;
  final List<String> reasons;

  SuspendedPlayer({
    required this.playerId,
    required this.firstName,
    required this.lastName,
    required this.pendingMatches,
    required this.reasons,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory SuspendedPlayer.fromJson(Map<String, dynamic> json) {
    final rawReasons = json['reasons'];
    final parsedReasons = rawReasons is List
        ? rawReasons.map((e) => e.toString()).toList()
        : <String>[];

    return SuspendedPlayer(
      playerId: (json['player_id'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      pendingMatches:
          int.tryParse((json['pending_matches'] ?? 0).toString()) ?? 0,
      reasons: parsedReasons,
    );
  }
}

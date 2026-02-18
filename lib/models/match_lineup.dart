class MatchLineupPlayer {
  final String playerId;
  final String playerName;
  final int shirtNumber;
  final String position;
  final bool isStarting;

  MatchLineupPlayer({
    required this.playerId,
    required this.playerName,
    required this.shirtNumber,
    required this.position,
    required this.isStarting,
  });

  factory MatchLineupPlayer.fromJson(Map<String, dynamic> json) {
    final players =
        json['players'] is Map<String, dynamic>
            ? json['players'] as Map<String, dynamic>
            : <String, dynamic>{};

    final firstName =
        (players['first_name'] ?? '').toString();
    final lastName =
        (players['last_name'] ?? '').toString();
    final fallbackName =
        (json['player_name'] ?? json['player_id'] ?? '')
            .toString();
    final fullName =
        '$firstName $lastName'.trim().isEmpty
            ? fallbackName
            : '$firstName $lastName'.trim();

    return MatchLineupPlayer(
      playerId: (json['player_id'] ?? '').toString(),
      playerName: fullName,
      shirtNumber: int.tryParse(
            (json['shirt_number'] ?? 0).toString(),
          ) ??
          0,
      position: (json['position'] ?? '').toString(),
      isStarting: json['is_starting'] == true,
    );
  }

  Map<String, dynamic> toSubmitJson() {
    return {
      "player_id": playerId,
      "shirt_number": shirtNumber,
      "position": position,
      "is_starting": isStarting,
    };
  }
}

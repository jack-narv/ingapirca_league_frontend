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
    return MatchLineupPlayer(
      playerId: json['player_id'],
      playerName:
          "${json['players']['first_name']} ${json['players']['last_name']}",
      shirtNumber: json['shirt_number'],
      position: json['position'],
      isStarting: json['is_starting'],
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

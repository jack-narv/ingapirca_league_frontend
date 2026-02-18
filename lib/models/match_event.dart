class MatchEvent {
  final String id;
  final String matchId;
  final String teamId;
  final String playerId;
  final int minute;
  final String eventType;
  final String? relatedPlayerId;
  final String? playerName;
  final int? shirtNumber;

  MatchEvent({
    required this.id,
    required this.matchId,
    required this.teamId,
    required this.playerId,
    required this.minute,
    required this.eventType,
    this.relatedPlayerId,
    this.playerName,
    this.shirtNumber,
  });

  factory MatchEvent.fromJson(Map<String, dynamic> json) {
    final playerFromInclude =
        json['players_match_events_player_idToplayers'];

    return MatchEvent(
      id: json['id'],
      matchId: json['match_id'],
      teamId: json['team_id'],
      playerId: json['player_id'],
      minute: json['minute'],
      eventType: json['event_type'],
      relatedPlayerId: json['related_player_id'],
      playerName: json['player_name'] ??
          (playerFromInclude != null
              ? "${playerFromInclude['first_name'] ?? ''} ${playerFromInclude['last_name'] ?? ''}"
                  .trim()
              : null) ??
          (json['players'] != null
              ? "${json['players']['first_name'] ?? ''} ${json['players']['last_name'] ?? ''}"
                  .trim()
              : null),
      shirtNumber: json['shirt_number'],
    );
  }
}

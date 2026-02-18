class MatchEvent {
  final String id;
  final String matchId;
  final String teamId;
  final String playerId;
  final int minute;
  final String eventType;
  final String? relatedPlayerId;

  MatchEvent({
    required this.id,
    required this.matchId,
    required this.teamId,
    required this.playerId,
    required this.minute,
    required this.eventType,
    this.relatedPlayerId,
  });

  factory MatchEvent.fromJson(Map<String, dynamic> json) {
    return MatchEvent(
      id: json['id'],
      matchId: json['match_id'],
      teamId: json['team_id'],
      playerId: json['player_id'],
      minute: json['minute'],
      eventType: json['event_type'],
      relatedPlayerId: json['related_player_id'],
    );
  }
}

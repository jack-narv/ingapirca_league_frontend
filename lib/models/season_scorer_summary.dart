class SeasonScorerPlayer {
  final String playerId;
  final String playerName;
  final String teamId;
  final String teamName;
  final int goals;

  SeasonScorerPlayer({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.teamName,
    required this.goals,
  });

  factory SeasonScorerPlayer.fromJson(Map<String, dynamic> json) {
    return SeasonScorerPlayer(
      playerId: (json['player_id'] ?? '').toString(),
      playerName: (json['player_name'] ?? '').toString(),
      teamId: (json['team_id'] ?? '').toString(),
      teamName: (json['team_name'] ?? '').toString(),
      goals: _toInt(json['goals']),
    );
  }
}

class SeasonScorerTeam {
  final String teamId;
  final String teamName;
  final int totalGoals;
  final List<SeasonScorerPlayer> players;

  SeasonScorerTeam({
    required this.teamId,
    required this.teamName,
    required this.totalGoals,
    required this.players,
  });

  factory SeasonScorerTeam.fromJson(Map<String, dynamic> json) {
    final playersJson = json['players'];

    return SeasonScorerTeam(
      teamId: (json['team_id'] ?? '').toString(),
      teamName: (json['team_name'] ?? '').toString(),
      totalGoals: _toInt(json['total_goals']),
      players: playersJson is List
          ? playersJson
              .whereType<Map<String, dynamic>>()
              .map(SeasonScorerPlayer.fromJson)
              .toList()
          : <SeasonScorerPlayer>[],
    );
  }
}

class SeasonScorerCategory {
  final String categoryId;
  final String categoryName;
  final List<SeasonScorerTeam> teams;
  final List<SeasonScorerPlayer> topPlayers;

  SeasonScorerCategory({
    required this.categoryId,
    required this.categoryName,
    required this.teams,
    required this.topPlayers,
  });

  factory SeasonScorerCategory.fromJson(Map<String, dynamic> json) {
    final teamsJson = json['teams'];
    final topPlayersJson = json['top_players'];

    return SeasonScorerCategory(
      categoryId: (json['category_id'] ?? '').toString(),
      categoryName: (json['category_name'] ?? '').toString(),
      teams: teamsJson is List
          ? teamsJson
              .whereType<Map<String, dynamic>>()
              .map(SeasonScorerTeam.fromJson)
              .toList()
          : <SeasonScorerTeam>[],
      topPlayers: topPlayersJson is List
          ? topPlayersJson
              .whereType<Map<String, dynamic>>()
              .map(SeasonScorerPlayer.fromJson)
              .toList()
          : <SeasonScorerPlayer>[],
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '').toString()) ?? 0;
}

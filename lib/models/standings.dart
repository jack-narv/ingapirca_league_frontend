class Standing {
  final String id;
  final String seasonId;
  final String teamId;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int points;
  final String teamName;
  final String? teamLogoUrl;
  final String? teamCategoryId;

  Standing({
    required this.id,
    required this.seasonId,
    required this.teamId,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.points,
    required this.teamName,
    this.teamLogoUrl,
    this.teamCategoryId,
  });

  int get goalDifference => goalsFor - goalsAgainst;

  factory Standing.fromJson(Map<String, dynamic> json) {
    final team = (json['teams'] as Map<String, dynamic>?) ?? {};

    return Standing(
      id: json['id']?.toString() ?? '',
      seasonId: json['season_id']?.toString() ?? '',
      teamId: json['team_id']?.toString() ?? '',
      played: _toInt(json['played']),
      wins: _toInt(json['wins']),
      draws: _toInt(json['draws']),
      losses: _toInt(json['losses']),
      goalsFor: _toInt(json['goals_for']),
      goalsAgainst: _toInt(json['goals_against']),
      points: _toInt(json['points']),
      teamName: team['name']?.toString() ?? 'Equipo',
      teamLogoUrl: team['logo_url']?.toString(),
      teamCategoryId: team['category_id']?.toString(),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

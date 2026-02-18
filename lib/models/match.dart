class Match{
  final String id;
  final String seasonId;
  final String? categoryId;
  final String homeTeamId;
  final String awayTeamId;
  final String venueId;
  final DateTime matchDate;
  final String status;
  final int homeScore;
  final int awayScore;
  final String? observations;

  Match({
    required this.id,
    required this.seasonId,
    this.categoryId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.venueId,
    required this.matchDate,
    required this.status,
    required this.homeScore,
    required this.awayScore,
    this.observations,
  });

  factory Match.fromJson(Map<String, dynamic> json){
    return Match(
      id: json['id'],
      seasonId: json['season_id'],
      categoryId: json['category_id'],
      homeTeamId: json['home_team_id'],
      awayTeamId: json['away_team_id'],
      venueId: json['venue_id'],
      matchDate: DateTime.parse(json['match_date']),
      status: json['status'],
      homeScore: json['home_score'],
      awayScore: json['away_score'],
      observations: json['observations'],
    );
  }
}

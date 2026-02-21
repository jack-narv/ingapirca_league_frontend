import 'package:ingapirca_league_frontend/core/utils/ecuador_time.dart';

class Match{
  final String id;
  final String seasonId;
  final String? categoryId;
  final String? journal;
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
    this.journal,
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
    final rawMatchDate = json['match_date']?.toString() ?? '';
    final matchDateEcuador = EcuadorTime.parseServerToEcuador(rawMatchDate);

    return Match(
      id: json['id'],
      seasonId: json['season_id'],
      categoryId: json['category_id'],
      journal: json['journal']?.toString(),
      homeTeamId: json['home_team_id'],
      awayTeamId: json['away_team_id'],
      venueId: json['venue_id'],
      matchDate: matchDateEcuador,
      status: json['status'],
      homeScore: json['home_score'],
      awayScore: json['away_score'],
      observations: json['observations'],
    );
  }
}

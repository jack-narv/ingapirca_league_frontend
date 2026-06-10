import 'cards_summary.dart';
import 'season_category.dart';
import 'suspension_summary.dart';
import 'team.dart';

class SeasonSanctionsOverview {
  final List<SeasonCategory> categories;
  final List<Team> teams;
  final List<CardsSummary> cardsSummary;
  final List<SuspensionSummary> suspensionsSummary;

  SeasonSanctionsOverview({
    required this.categories,
    required this.teams,
    required this.cardsSummary,
    required this.suspensionsSummary,
  });

  factory SeasonSanctionsOverview.fromJson(Map<String, dynamic> json) {
    final categories = (json['categories'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SeasonCategory.fromJson)
        .toList();
    final teams = (json['teams'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Team.fromJson)
        .toList();
    final cardsSummary = (json['cards_summary'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CardsSummary.fromJson)
        .toList();
    final suspensionsSummary =
        (json['suspensions_summary'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SuspensionSummary.fromJson)
            .toList();

    return SeasonSanctionsOverview(
      categories: categories,
      teams: teams,
      cardsSummary: cardsSummary,
      suspensionsSummary: suspensionsSummary,
    );
  }
}

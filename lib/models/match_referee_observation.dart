import 'package:ingapirca_league_frontend/core/utils/ecuador_time.dart';

class MatchRefereeObservation {
  final String id;
  final String matchId;
  final String refereeId;
  final String observation;
  final String status;
  final DateTime? submittedAt;
  final String? refereeName;
  final DateTime? matchDate;
  final String? matchStatus;

  MatchRefereeObservation({
    required this.id,
    required this.matchId,
    required this.refereeId,
    required this.observation,
    required this.status,
    this.submittedAt,
    this.refereeName,
    this.matchDate,
    this.matchStatus,
  });

  factory MatchRefereeObservation.fromJson(
    Map<String, dynamic> json,
  ) {
    final referee = json['referees'];
    final match = json['matches'];
    final submittedAtRaw = json['submitted_at'] ?? json['submittedAt'];
    final matchDateRaw = match is Map<String, dynamic>
        ? match['match_date']
        : null;

    final refereeName = referee is Map<String, dynamic>
        ? "${(referee['first_name'] ?? '').toString()} ${(referee['last_name'] ?? '').toString()}".trim()
        : null;

    return MatchRefereeObservation(
      id: (json['id'] ?? '').toString(),
      matchId: (json['match_id'] ?? '').toString(),
      refereeId: (json['referee_id'] ?? '').toString(),
      observation: (json['observation'] ?? '').toString(),
      status: (json['status'] ?? 'DRAFT').toString(),
      submittedAt: submittedAtRaw == null
          ? null
          : EcuadorTime.parseServerToEcuador(
              submittedAtRaw.toString(),
            ),
      refereeName: refereeName,
      matchDate: matchDateRaw == null
          ? null
          : EcuadorTime.parseServerToEcuador(
              matchDateRaw.toString(),
            ),
      matchStatus: match is Map<String, dynamic>
          ? match['status']?.toString()
          : null,
    );
  }
}

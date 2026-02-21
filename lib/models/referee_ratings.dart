class RefereeRating {
  final String id;
  final String matchId;
  final String refereeId;
  final String teamId;
  final int rating;
  final String? comment;
  final DateTime? submittedAt;
  final String? refereeName;
  final String? teamName;
  final DateTime? matchDate;
  final String? matchStatus;

  RefereeRating({
    required this.id,
    required this.matchId,
    required this.refereeId,
    required this.teamId,
    required this.rating,
    this.comment,
    this.submittedAt,
    this.refereeName,
    this.teamName,
    this.matchDate,
    this.matchStatus,
  });

  factory RefereeRating.fromJson(Map<String, dynamic> json) {
    final referee = json['referees'];
    final team = json['teams'];
    final match = json['matches'];
    final submittedAtRaw = json['submitted_at'] ?? json['submittedAt'];
    final matchDateRaw = match is Map<String, dynamic>
        ? match['match_date']
        : null;

    final refereeName = referee is Map<String, dynamic>
        ? "${(referee['first_name'] ?? '').toString()} ${(referee['last_name'] ?? '').toString()}".trim()
        : null;

    return RefereeRating(
      id: (json['id'] ?? '').toString(),
      matchId: (json['match_id'] ?? '').toString(),
      refereeId: (json['referee_id'] ?? '').toString(),
      teamId: (json['team_id'] ?? '').toString(),
      rating: int.tryParse((json['rating'] ?? 0).toString()) ?? 0,
      comment: json['comment']?.toString(),
      submittedAt: submittedAtRaw == null
          ? null
          : DateTime.tryParse(submittedAtRaw.toString()),
      refereeName: refereeName,
      teamName: team is Map<String, dynamic>
          ? team['name']?.toString()
          : null,
      matchDate: matchDateRaw == null
          ? null
          : DateTime.tryParse(matchDateRaw.toString()),
      matchStatus: match is Map<String, dynamic>
          ? match['status']?.toString()
          : null,
    );
  }
}

class RefereeAverageRating {
  final double? average;
  final int count;

  RefereeAverageRating({
    required this.average,
    required this.count,
  });

  factory RefereeAverageRating.fromJson(Map<String, dynamic> json) {
    final avg = json['_avg'];
    final count = json['_count'];

    return RefereeAverageRating(
      average: avg is Map<String, dynamic>
          ? double.tryParse((avg['rating'] ?? '').toString())
          : null,
      count: count is Map<String, dynamic>
          ? int.tryParse((count['rating'] ?? 0).toString()) ?? 0
          : 0,
    );
  }
}

class Season {
  final String id;
  final String leagueId;
  final String name;
  final String status;
  final DateTime startDate;
  final DateTime endDate;

  Season({
    required this.id,
    required this.leagueId,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
      id: json['id'],
      leagueId: json['league_id'],
      name: json['name'],
      status: json['status'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
    );
  }
}

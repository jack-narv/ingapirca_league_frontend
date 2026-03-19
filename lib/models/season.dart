class Season {
  final String id;
  final String leagueId;
  final String name;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final int twoYellowsMatchesAffected;
  final int directRedMatchesAffected;
  final int gameNumberPlayers;

  Season({
    required this.id,
    required this.leagueId,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.twoYellowsMatchesAffected,
    required this.directRedMatchesAffected,
    required this.gameNumberPlayers,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    DateTime parseDateOnly(dynamic raw) {
      final text = raw?.toString() ?? '';
      final core = text.length >= 10 ? text.substring(0, 10) : text;
      final parts = core.split('-');
      if (parts.length == 3) {
        final year = int.tryParse(parts[0]) ?? 1970;
        final month = int.tryParse(parts[1]) ?? 1;
        final day = int.tryParse(parts[2]) ?? 1;
        return DateTime(year, month, day);
      }
      return DateTime.parse(text);
    }

    return Season(
      id: json['id'],
      leagueId: json['league_id'],
      name: json['name'],
      status: json['status'],
      startDate: parseDateOnly(json['start_date']),
      endDate: parseDateOnly(json['end_date']),
      twoYellowsMatchesAffected: int.tryParse(
            (json['two_yellows_matches_affected'] ?? 1).toString(),
          ) ??
          1,
      directRedMatchesAffected: int.tryParse(
            (json['direct_red_matches_affected'] ?? 1).toString(),
          ) ??
          1,
      gameNumberPlayers: int.tryParse(
            (json['game_number_players'] ?? 11).toString(),
          ) ??
          11,
    );
  }
}

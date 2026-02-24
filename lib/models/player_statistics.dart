class PlayerStatisticsPlayer {
  final String id;
  final String firstName;
  final String lastName;
  final String? photoUrl;

  PlayerStatisticsPlayer({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.photoUrl,
  });

  String get fullName {
    final full = "$firstName $lastName".trim();
    return full.isEmpty ? id : full;
  }

  factory PlayerStatisticsPlayer.fromJson(Map<String, dynamic> json) {
    return PlayerStatisticsPlayer(
      id: (json['id'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      photoUrl: json['photo_url']?.toString(),
    );
  }
}

class PlayerStatisticsSeason {
  final String id;
  final String name;
  final String status;

  PlayerStatisticsSeason({
    required this.id,
    required this.name,
    required this.status,
  });

  factory PlayerStatisticsSeason.fromJson(Map<String, dynamic> json) {
    return PlayerStatisticsSeason(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
    );
  }
}

class PlayerStatistics {
  final String playerId;
  final String seasonId;
  final int goals;
  final int assists;
  final int yellowCards;
  final int redCards;
  final PlayerStatisticsPlayer? player;
  final PlayerStatisticsSeason? season;

  PlayerStatistics({
    required this.playerId,
    required this.seasonId,
    required this.goals,
    required this.assists,
    required this.yellowCards,
    required this.redCards,
    this.player,
    this.season,
  });

  int get totalCards => yellowCards + redCards;

  factory PlayerStatistics.fromJson(Map<String, dynamic> json) {
    final playerJson = json['players'];
    final seasonJson = json['seasons'];

    return PlayerStatistics(
      playerId: (json['player_id'] ?? '').toString(),
      seasonId: (json['season_id'] ?? '').toString(),
      goals: _toInt(json['goals']),
      assists: _toInt(json['assists']),
      yellowCards: _toInt(json['yellow_cards']),
      redCards: _toInt(json['red_cards']),
      player: playerJson is Map<String, dynamic>
          ? PlayerStatisticsPlayer.fromJson(playerJson)
          : null,
      season: seasonJson is Map<String, dynamic>
          ? PlayerStatisticsSeason.fromJson(seasonJson)
          : null,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}

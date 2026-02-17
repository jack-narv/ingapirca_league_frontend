class PlayerTeamInfo {
  final String teamId;
  final String teamName;
  final int shirtNumber;
  final String position;

  PlayerTeamInfo({
    required this.teamId,
    required this.teamName,
    required this.shirtNumber,
    required this.position,
  });

  factory PlayerTeamInfo.fromJson(Map<String, dynamic> json) {
    final team = json['teams'];
    final teamMap =
        team is Map<String, dynamic> ? team : <String, dynamic>{};

    return PlayerTeamInfo(
      teamId: (json['team_id'] ?? '').toString(),
      teamName: (teamMap['name'] ?? '').toString(),
      shirtNumber:
          int.tryParse((json['shirt_number'] ?? 0).toString()) ?? 0,
      position: (json['position'] ?? '').toString(),
    );
  }
}

class Player {
  final String id;
  final String firstName;
  final String lastName;
  final DateTime dateOfBirth;
  final String nationality;
  final String? photoUrl;
  final List<PlayerTeamInfo> teamInfo;

  Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.nationality,
    this.photoUrl,
    this.teamInfo = const [],
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['_id'] ?? json['player_id'];
    final rawBirthDate =
        json['date_of_birth'] ?? json['birth_date'];
    final rawTeamInfo = json['team_player'];
    final teamInfo = rawTeamInfo is List
        ? rawTeamInfo
            .whereType<Map<String, dynamic>>()
            .map(PlayerTeamInfo.fromJson)
            .toList()
        : <PlayerTeamInfo>[];

    return Player(
      id: rawId?.toString() ?? '',
      firstName: (json['first_name'] ?? json['firstName'] ?? '')
          .toString(),
      lastName: (json['last_name'] ?? json['lastName'] ?? '')
          .toString(),
      dateOfBirth: rawBirthDate != null
          ? DateTime.parse(rawBirthDate.toString())
          : DateTime(1970, 1, 1),
      nationality:
          (json['nationality'] ?? '').toString(),
      photoUrl: json['photo_url'],
      teamInfo: teamInfo,
    );
  }
}

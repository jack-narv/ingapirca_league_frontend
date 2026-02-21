import 'player.dart';

class TeamPlayer {
  final String id;
  final String playerId;
  final int shirtNumber;
  final String position;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final Player player;

  TeamPlayer({
    required this.id,
    required this.playerId,
    required this.shirtNumber,
    required this.position,
    required this.joinedAt,
    this.leftAt,
    required this.player,
  });

  factory TeamPlayer.fromJson(Map<String, dynamic> json) {
    final playerJson = json['players'] ?? json['player'];
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

    return TeamPlayer(
      id: (json['id'] ?? json['_id']).toString(),
      playerId: (json['player_id'] ??
              (playerJson is Map<String, dynamic>
                  ? playerJson['id']
                  : null) ??
              '')
          .toString(),
      shirtNumber: int.tryParse(
            (json['shirt_number'] ?? 0).toString(),
          ) ??
          0,
      position: (json['position'] ?? '').toString(),
      joinedAt: parseDateOnly(json['joined_at']),
      leftAt: json['left_at'] != null
          ? parseDateOnly(json['left_at'])
          : null,
      player: Player.fromJson(
        playerJson is Map<String, dynamic>
            ? playerJson
            : <String, dynamic>{},
      ),
    );
  }
}

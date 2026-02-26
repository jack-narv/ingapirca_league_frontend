class CardsSummary {
  final String playerId;
  final String firstName;
  final String lastName;
  final int? shirtNumber;
  final int yellowCards;
  final int redDirectCards;

  CardsSummary({
    required this.playerId,
    required this.firstName,
    required this.lastName,
    required this.shirtNumber,
    required this.yellowCards,
    required this.redDirectCards,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory CardsSummary.fromJson(Map<String, dynamic> json) {
    return CardsSummary(
      playerId: (json['player_id'] ?? '').toString(),
      firstName: (json['first_name'] ?? '').toString(),
      lastName: (json['last_name'] ?? '').toString(),
      shirtNumber: json['shirt_number'] == null
          ? null
          : int.tryParse(json['shirt_number'].toString()),
      yellowCards:
          int.tryParse((json['yellow_cards'] ?? 0).toString()) ?? 0,
      redDirectCards:
          int.tryParse((json['red_direct_cards'] ?? 0).toString()) ?? 0,
    );
  }
}

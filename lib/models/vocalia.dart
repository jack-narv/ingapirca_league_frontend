class VocaliaValue {
  final String id;
  final String concept;
  final double amount;

  VocaliaValue({
    required this.id,
    required this.concept,
    required this.amount,
  });

  factory VocaliaValue.fromJson(Map<String, dynamic> json) {
    return VocaliaValue(
      id: (json['id'] ?? '').toString(),
      concept: (json['concept'] ?? '').toString(),
      amount: _parseDouble(json['amount']),
    );
  }
}

class MatchVocalia {
  final String id;
  final String matchId;
  final String teamId;
  final String? teamName;
  final List<VocaliaValue> values;
  final double totalAmount;

  MatchVocalia({
    required this.id,
    required this.matchId,
    required this.teamId,
    required this.teamName,
    required this.values,
    required this.totalAmount,
  });

  factory MatchVocalia.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];

    return MatchVocalia(
      id: (json['id'] ?? '').toString(),
      matchId: (json['match_id'] ?? '').toString(),
      teamId: (json['team_id'] ?? '').toString(),
      teamName: json['team_name']?.toString(),
      values: rawValues is List
          ? rawValues
              .whereType<Map<String, dynamic>>()
              .map(VocaliaValue.fromJson)
              .toList()
          : const <VocaliaValue>[],
      totalAmount: _parseDouble(json['total_amount']),
    );
  }
}

double _parseDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse((value ?? '').toString()) ?? 0;
}

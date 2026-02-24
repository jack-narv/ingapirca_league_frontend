class Venue{
  final String id;
  final String name;
  final String? address;
  final List<String> seasonIds;

  Venue({
    required this.id,
    required this.name,
    this.address,
    this.seasonIds = const [],
  });

  factory Venue.fromJson(Map<String, dynamic> json){
    final rawSeasonVenues = json['season_venues'];
    final seasonIds = <String>[];
    if (rawSeasonVenues is List) {
      for (final item in rawSeasonVenues) {
        if (item is Map<String, dynamic>) {
          final seasonId = item['season_id']?.toString() ?? '';
          if (seasonId.isNotEmpty) {
            seasonIds.add(seasonId);
          }
        }
      }
    }

    return Venue(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      address: json['address']?.toString(),
      seasonIds: seasonIds,
    );
  }
}

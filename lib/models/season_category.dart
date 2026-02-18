class SeasonCategory {
  final String id;
  final String seasonId;
  final String name;
  final int sortOrder;
  final bool isActive;

  SeasonCategory({
    required this.id,
    required this.seasonId,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  factory SeasonCategory.fromJson(Map<String, dynamic> json) {
    return SeasonCategory(
      id: json['id'],
      seasonId: json['season_id'],
      name: json['name'],
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }
}

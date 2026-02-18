class Team{
  final String id;
  final String? categoryId;
  final String name;
  final int? foundedYear;
  final String? logoUrl;

  Team({
    required this.id,
    this.categoryId,
    required this.name,
    this.foundedYear,
    this.logoUrl,
  });

  factory Team.fromJson(Map<String, dynamic> json){
    return Team(
        id: json['id'],
        categoryId: json['category_id'],
        name: json['name'],
        foundedYear: json['founded_year'],
        logoUrl: json['logo_url'],
      );
  }

}


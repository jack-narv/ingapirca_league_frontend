class Team{
  final String id;
  final String name;
  final int? foundedYear;
  final String? logoUrl;

  Team({
    required this.id,
    required this.name,
    this.foundedYear,
    this.logoUrl,
  });

  factory Team.fromJson(Map<String, dynamic> json){
    return Team(
        id: json['id'],
        name: json['name'],
        foundedYear: json['founded_year'],
        logoUrl: json['logo_url'],
      );
  }

}


class League {
  final String id;
  final String name;
  final String country;
  final String city;

  League({
    required this.id,
    required this.name,
    required this.country,
    required this.city
  });

  factory League.fromJson(Map<String, dynamic> json){
    return League(
      id: json['id'],
      name: json['name'],
      country: json['country'],
      city: json['city'],
    );
  }
}
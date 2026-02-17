class Venue{
  final String id;
  final String name;
  final String? address;

  Venue({
    required this.id,
    required this.name,
    this.address,
  });

  factory Venue.fromJson(Map<String, dynamic> json){
    return Venue(
      id: json['id'],
      name: json['name'],
      address: json['address'],
    );
  }
}
class University {
  final String id;
  final String name;
  final String? domain;
  final String? logoUrl;

  University({
    required this.id,
    required this.name,
    this.domain,
    this.logoUrl,
  });

  factory University.fromJson(Map<String, dynamic> json) {
    return University(
      id: json['id'],
      name: json['name'],
      domain: json['domain'],
      logoUrl: json['logo_url'],
    );
  }
}

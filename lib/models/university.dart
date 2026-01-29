class University {
  final String id;
  final String name;
  final String shortName; // e.g., "UH", "HCC"
  final String? location;
  final String? websiteUrl;
  final String? logoUrl;
  final bool isActive;

  University({
    required this.id,
    required this.name,
    required this.shortName,
    this.location,
    this.websiteUrl,
    this.logoUrl,
    this.isActive = true,
  });

  factory University.fromJson(Map<String, dynamic> json) {
    return University(
      id: json['id'],
      name: json['name'],
      shortName: json['short_name'] ?? '',
      location: json['location'],
      websiteUrl: json['website_url'],
      logoUrl: json['logo_url'],
      isActive: json['is_active'] ?? true,
    );
  }

  // Helper to get local asset logo path
  String get assetLogoPath {
    switch (shortName) {
      case 'UH':
        return 'assets/UH_logo.png';
      case 'HCC':
        return 'assets/HCCS_Logo.png';
      default:
        return '';
    }
  }
}

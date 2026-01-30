class University {
  final String id;
  final String name;
  final String shortName; // e.g., "UH", "HCC"
  final String? domain; // e.g., "uh.edu", "hccs.edu"
  final String? location;
  final String? websiteUrl;
  final String? logoUrl;
  final String? primaryColor; // e.g., "#C8102E"
  final String? secondaryColor;
  final bool isActive;

  University({
    required this.id,
    required this.name,
    required this.shortName,
    this.domain,
    this.location,
    this.websiteUrl,
    this.logoUrl,
    this.primaryColor,
    this.secondaryColor,
    this.isActive = true,
  });

  factory University.fromJson(Map<String, dynamic> json) {
    return University(
      id: json['id'],
      name: json['name'],
      shortName: json['short_name'] ?? '',
      domain: json['domain'],
      location: json['location'],
      websiteUrl: json['website_url'],
      logoUrl: json['logo_url'],
      primaryColor: json['primary_color'],
      secondaryColor: json['secondary_color'],
      isActive: json['is_active'] ?? true,
    );
  }

  // Helper to get local asset logo path
  String get assetLogoPath {
    switch (shortName.toUpperCase()) {
      case 'UH':
        return 'assets/UH_logo.png';
      case 'HCC':
        return 'assets/HCCS_Logo.png';
      default:
        return '';
    }
  }

  // Helper to parse hex color
  int? get primaryColorInt {
    if (primaryColor == null) return null;
    final hex = primaryColor!.replaceFirst('#', '');
    return int.tryParse('FF$hex', radix: 16);
  }
}

class StudySpot {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final List<String> perks;
  final String? incentive;

  StudySpot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.perks = const [],
    this.incentive,
  });

  factory StudySpot.fromJson(Map<String, dynamic> json) {
    // GeoJSON parsing if using PostGIS or just custom selection
    // Assuming backend select provides lat/long or we parse the geometry
    // For simplicity in previous patterns, we might fetch 'location' and need to parse it,
    // or better, we modify the query to return lat/long columns.
    // Let's assume the query will use st_y(location::geometry) as lat, etc.
    // OR, if we use the simple Supabase client without custom SQL, we might need a stored procedure or just use the columns if we added them.
    // Wait, I declared 'location geography(point)'. Supabase selects usually return this as a GeoJSON string or WKT.
    // It's easier if we create a View or use a Function.
    // BUT for MVP, let's just parse the location if it's returned as GeoJSON, OR update the table to have lat/long columns for simplicity?
    // Actually, `profile` table used lat/long columns. I should probably use lat/long columns for `study_spots` too for consistency and ease of use in Flutter without extra parsing libs.

    // Let's stick to the model assuming we get 'lat' and 'long'.
    // Usage: `select *, st_y(location::geometry) as lat, st_x(location::geometry) as long`

    return StudySpot(
      id: json['id'],
      name: json['name'],
      latitude: (json['lat'] ?? 0.0).toDouble(),
      longitude: (json['long'] ?? 0.0).toDouble(),
      imageUrl: json['image_url'],
      perks: List<String>.from(json['perks'] ?? []),
      incentive: json['incentive'],
    );
  }
}

class SerendipityMatch {
  final String id;
  final String userA;
  final String userB;
  final String matchType; // 'proximity', 'constellation', 'temporal'
  final bool accepted;
  final int? rating;
  final DateTime createdAt;

  SerendipityMatch({
    required this.id,
    required this.userA,
    required this.userB,
    required this.matchType,
    this.accepted = false,
    this.rating,
    required this.createdAt,
  });

  factory SerendipityMatch.fromJson(Map<String, dynamic> json) {
    return SerendipityMatch(
      id: json['id'] as String,
      userA: json['user_a'] as String,
      userB: json['user_b'] as String,
      matchType: json['match_type'] as String,
      accepted: json['accepted'] as bool? ?? false,
      rating: json['rating'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_a': userA,
      'user_b': userB,
      'match_type': matchType,
      'accepted': accepted,
      'rating': rating,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class SpotReview {
  final String id;
  final String spotId;
  final String userId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  SpotReview({
    required this.id,
    required this.spotId,
    required this.userId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory SpotReview.fromJson(Map<String, dynamic> json) {
    return SpotReview(
      id: json['id'],
      spotId: json['spot_id'],
      userId: json['user_id'],
      rating: json['rating'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spot_id': spotId,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
    };
  }
}

class Review {
  final String id;
  final String reviewerId;
  final String revieweeId;
  final String appointmentId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.reviewerId,
    required this.revieweeId,
    required this.appointmentId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      reviewerId: json['reviewer_id'],
      revieweeId: json['reviewee_id'],
      appointmentId: json['appointment_id'],
      rating: json['rating'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewer_id': reviewerId,
      'reviewee_id': revieweeId,
      'appointment_id': appointmentId,
      'rating': rating,
      'comment': comment,
    };
  }
}

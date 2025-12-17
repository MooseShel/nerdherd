class Report {
  final String id;
  final String reporterId;
  final String reportedId;
  final String reason;
  final String status; // 'pending', 'resolved', 'dismissed'
  final DateTime createdAt;

  Report({
    required this.id,
    required this.reporterId,
    required this.reportedId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: json['id'].toString(),
      reporterId: json['reporter_id'],
      reportedId: json['reported_id'],
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'reported_id': reportedId,
      'reason': reason,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

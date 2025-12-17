class SupportTicket {
  final String id;
  final String userId;
  final String subject;
  final String message;
  final String status; // 'open', 'closed'
  final DateTime createdAt;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'].toString(),
      userId: json['user_id'],
      subject: json['subject'] ?? 'No Subject',
      message: json['message'] ?? '',
      status: json['status'] ?? 'open',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subject': subject,
      'message': message,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

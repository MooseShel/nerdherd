class Appointment {
  final String id;
  final String hostId;
  final String attendeeId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final String? message;
  final DateTime createdAt;
  final double price;
  final bool isPaid;

  Appointment({
    required this.id,
    required this.hostId,
    required this.attendeeId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.message,
    required this.createdAt,
    this.price = 0.0,
    this.isPaid = false,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      hostId: json['host_id'],
      attendeeId: json['attendee_id'],
      startTime: DateTime.parse(json['start_time']).toLocal(),
      endTime: DateTime.parse(json['end_time']).toLocal(),
      status: json['status'],
      message: json['message'],
      createdAt: DateTime.parse(json['created_at']),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isPaid: json['is_paid'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'host_id': hostId,
      'attendee_id': attendeeId,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
      'status': status,
      'message': message,
      'created_at': createdAt.toIso8601String(),
      'price': price,
      'is_paid': isPaid,
    };
  }
}

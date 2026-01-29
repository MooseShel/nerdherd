class Course {
  final String id;
  final String universityId;
  final String? departmentId;
  final String courseCode; // e.g., "COSC 1336"
  final String courseNumber; // e.g., "1336"
  final String title;
  final String? description;
  final int? credits;
  final bool isActive;

  Course({
    required this.id,
    required this.universityId,
    this.departmentId,
    required this.courseCode,
    required this.courseNumber,
    required this.title,
    this.description,
    this.credits,
    this.isActive = true,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      universityId: json['university_id'],
      departmentId: json['department_id'],
      courseCode: json['course_code'] ??
          json['code'] ??
          '', // Fallback to 'code' for compatibility
      courseNumber: json['course_number'] ?? '',
      title: json['title'],
      description: json['description'],
      credits: json['credits'],
      isActive: json['is_active'] ?? true,
    );
  }

  String get fullLabel => "$courseCode: $title";
}

class Course {
  final String id;
  final String universityId;
  final String code;
  final String title;
  final String? term;

  Course({
    required this.id,
    required this.universityId,
    required this.code,
    required this.title,
    this.term,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      universityId: json['university_id'],
      code: json['code'],
      title: json['title'],
      term: json['term'],
    );
  }

  String get fullLabel => "$code: $title";
}

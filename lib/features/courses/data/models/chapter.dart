class Chapter {
  final String id;
  final String courseId;
  final String title;
  final int position;

  const Chapter({
    required this.id,
    required this.courseId,
    required this.title,
    required this.position,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) => Chapter(
    id: json['id'] as String,
    courseId: json['course_id'] as String,
    title: json['title'] as String? ?? '',
    position: json['position'] as int? ?? 0,
  );
}

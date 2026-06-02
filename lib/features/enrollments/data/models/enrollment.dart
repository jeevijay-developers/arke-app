class Enrollment {
  final String id;
  final String userId;
  final String courseId;
  final int progressPercent;
  final int completedLessons;
  final String? lastLessonTitle;
  final DateTime? lastAccessedAt;
  final bool isActive;
  final DateTime createdAt;

  // Joined course fields
  final String? courseTitle;
  final String? courseSubject;
  final String? courseThumbnailUrl;
  final String? courseEducatorName;
  final int? courseTotalLessons;

  const Enrollment({
    required this.id,
    required this.userId,
    required this.courseId,
    required this.progressPercent,
    required this.completedLessons,
    this.lastLessonTitle,
    this.lastAccessedAt,
    required this.isActive,
    required this.createdAt,
    this.courseTitle,
    this.courseSubject,
    this.courseThumbnailUrl,
    this.courseEducatorName,
    this.courseTotalLessons,
  });

  double get progressFraction => progressPercent / 100.0;

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    final course = json['courses'] as Map<String, dynamic>?;
    return Enrollment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      courseId: json['course_id'] as String,
      progressPercent: json['progress_percent'] as int? ?? 0,
      completedLessons: json['completed_lessons'] as int? ?? 0,
      lastLessonTitle: json['last_lesson_title'] as String?,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      courseTitle: course?['name'] as String?,
      courseSubject: course?['subject'] as String?,
      courseThumbnailUrl: course?['thumbnail_url'] as String?,
      courseEducatorName: course?['educator_name'] as String?,
      courseTotalLessons: course?['total_lessons'] as int?,
    );
  }
}

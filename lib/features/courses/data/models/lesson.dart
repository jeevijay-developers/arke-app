class Lesson {
  final String id;
  final String courseId;
  final String chapterId;
  final String title;
  final int position;
  final int durationSeconds;
  final String? videoUrl;
  final bool isFreePreview;
  final String type;

  const Lesson({
    required this.id,
    required this.courseId,
    required this.chapterId,
    required this.title,
    required this.position,
    required this.durationSeconds,
    this.videoUrl,
    required this.isFreePreview,
    required this.type,
  });

  int get durationMin => (durationSeconds / 60).ceil();

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
    id: json['id'] as String,
    courseId: json['course_id'] as String,
    chapterId: json['chapter_id'] as String,
    title: json['title'] as String? ?? '',
    position: json['position'] as int? ?? 0,
    durationSeconds: json['duration_seconds'] as int? ?? 0,
    videoUrl: json['video_url'] as String?,
    isFreePreview: json['is_free_preview'] as bool? ?? false,
    type: json['type'] as String? ?? 'video',
  );
}

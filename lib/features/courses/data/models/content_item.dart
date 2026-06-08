class ContentItem {
  final String id;
  final String courseId;
  final String folderId;
  final String type; // 'live_class' | 'pdf' | 'recorded_lecture' | 'video' | 'test'
  final String title;
  final String? description;
  final String? fileUrl;
  final String? videoUrl;
  final String? videoSource; // 's3' | 'youtube'
  final String? zoomLink;
  final DateTime? scheduledAt;
  final String? testId;
  final int order;
  final bool isFreePreview;

  const ContentItem({
    required this.id,
    required this.courseId,
    required this.folderId,
    required this.type,
    required this.title,
    this.description,
    this.fileUrl,
    this.videoUrl,
    this.videoSource,
    this.zoomLink,
    this.scheduledAt,
    this.testId,
    this.order = 0,
    this.isFreePreview = false,
  });

  bool get isLiveClass => type == 'live_class';
  bool get isPdf => type == 'pdf';
  bool get isRecordedLecture => type == 'recorded_lecture';
  bool get isVideo => type == 'video';
  bool get isTest => type == 'test';

  bool get isLiveNow {
    if (!isLiveClass || scheduledAt == null) return false;
    final now = DateTime.now();
    final diff = now.difference(scheduledAt!);
    return diff.inMinutes >= 0 && diff.inHours < 2;
  }

  bool get isUpcoming {
    if (!isLiveClass || scheduledAt == null) return false;
    return scheduledAt!.isAfter(DateTime.now());
  }

  bool get isPastLive {
    if (!isLiveClass) return false;
    if (scheduledAt == null) return true;
    return scheduledAt!.isBefore(DateTime.now()) && !isLiveNow;
  }

  factory ContentItem.fromJson(Map<String, dynamic> j) => ContentItem(
        id: j['id'] as String,
        courseId: j['course_id'] as String,
        folderId: j['folder_id'] as String,
        type: j['type'] as String? ?? 'video',
        title: j['title'] as String? ?? '',
        description: j['description'] as String?,
        fileUrl: j['file_url'] as String?,
        videoUrl: j['video_url'] as String?,
        videoSource: j['video_source'] as String?,
        zoomLink: j['zoom_link'] as String?,
        scheduledAt: j['scheduled_at'] != null
            ? DateTime.tryParse(j['scheduled_at'] as String)
            : null,
        testId: j['test_id'] as String?,
        order: j['order'] as int? ?? 0,
        isFreePreview: j['is_free_preview'] as bool? ?? false,
      );
}

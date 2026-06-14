class LiveClass {
  final String id;
  final String title;
  final String subject;
  final String educatorName;
  final String? educatorAvatar;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? meetingUrl;
  final String? zoomMeetingId;
  final String? zoomMeetingPassword;
  final String status;
  final String? description;
  final String? recordingUrl;
  final String? courseId;
  final String? slug;

  const LiveClass({
    required this.id,
    required this.title,
    required this.subject,
    required this.educatorName,
    this.educatorAvatar,
    required this.startsAt,
    this.endsAt,
    this.meetingUrl,
    this.zoomMeetingId,
    this.zoomMeetingPassword,
    required this.status,
    this.description,
    this.recordingUrl,
    this.courseId,
    this.slug,
  });

  /// Resolved join URL: explicit meeting_url wins, else construct from zoom_meeting_id + password.
  String? get resolvedMeetingUrl {
    if (meetingUrl != null && meetingUrl!.isNotEmpty) return meetingUrl;
    if (zoomMeetingId != null && zoomMeetingId!.isNotEmpty) {
      final base = 'https://zoom.us/j/$zoomMeetingId';
      if (zoomMeetingPassword != null && zoomMeetingPassword!.isNotEmpty) {
        return '$base?pwd=$zoomMeetingPassword';
      }
      return base;
    }
    return null;
  }

  bool get isLive => status == 'live';
  bool get isPast => status == 'completed' || status == 'cancelled';

  factory LiveClass.fromJson(Map<String, dynamic> json) => LiveClass(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    subject: json['subject'] as String? ?? '',
    educatorName: json['educator_name'] as String? ?? '',
    educatorAvatar: json['educator_avatar'] as String?,
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at'] as String) : null,
    meetingUrl: json['meeting_url'] as String?,
    zoomMeetingId: json['zoom_meeting_id'] as String?,
    zoomMeetingPassword: json['zoom_meeting_password'] as String?,
    status: json['status'] as String? ?? 'scheduled',
    description: json['description'] as String?,
    recordingUrl: json['recording_url'] as String?,
    courseId: json['course_id'] as String?,
    slug: json['slug'] as String?,
  );
}

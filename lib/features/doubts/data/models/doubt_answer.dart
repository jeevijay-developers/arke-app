class DoubtAnswer {
  final String id;
  final String doubtId;
  final String responderId;
  final String responderRole;
  final String answerText;
  final String? imageUrl;
  final int helpfulCount;
  final DateTime createdAt;

  const DoubtAnswer({
    required this.id,
    required this.doubtId,
    required this.responderId,
    required this.responderRole,
    required this.answerText,
    this.imageUrl,
    required this.helpfulCount,
    required this.createdAt,
  });

  bool get isTeacher => responderRole == 'teacher';
  bool get isAi => responderRole == 'ai';

  factory DoubtAnswer.fromJson(Map<String, dynamic> json) => DoubtAnswer(
    id: json['id'] as String,
    doubtId: json['doubt_id'] as String,
    responderId: json['responder_id'] as String,
    responderRole: json['responder_role'] as String? ?? 'teacher',
    answerText: json['answer_text'] as String? ?? '',
    imageUrl: json['image_url'] as String?,
    helpfulCount: json['helpful_count'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

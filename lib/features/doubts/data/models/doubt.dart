class Doubt {
  final String id;
  final String userId;
  final String subject;
  final String? topic;
  final String questionText;
  final String? imageUrl;
  final String status;
  final String? aiAnswer;
  final String routedTo;
  final bool aiEscalated;
  final String? resolutionType;
  final DateTime createdAt;

  const Doubt({
    required this.id,
    required this.userId,
    required this.subject,
    this.topic,
    required this.questionText,
    this.imageUrl,
    required this.status,
    this.aiAnswer,
    required this.routedTo,
    required this.aiEscalated,
    this.resolutionType,
    required this.createdAt,
  });

  bool get isAiSolved => status == 'ai_answered' || (status == 'answered' && routedTo == 'ai');
  bool get isAnswered => status == 'answered' || status == 'ai_answered';
  bool get isPending => status == 'pending';

  factory Doubt.fromJson(Map<String, dynamic> json) => Doubt(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    subject: json['subject'] as String? ?? '',
    topic: json['topic'] as String?,
    questionText: json['question_text'] as String? ?? '',
    imageUrl: json['image_url'] as String?,
    status: json['status'] as String? ?? 'pending',
    aiAnswer: json['ai_answer'] as String?,
    routedTo: json['routed_to'] as String? ?? 'ai',
    aiEscalated: json['ai_escalated'] as bool? ?? false,
    resolutionType: json['resolution_type'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

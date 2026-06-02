class MentorMessage {
  final String id;
  final String senderId;
  final String? recipientId;
  final String? groupId;
  final String conversationType; // 'direct' | 'group'
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;

  const MentorMessage({
    required this.id,
    required this.senderId,
    this.recipientId,
    this.groupId,
    required this.conversationType,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  factory MentorMessage.fromJson(Map<String, dynamic> j) => MentorMessage(
        id: j['id'] as String,
        senderId: j['sender_id'] as String,
        recipientId: j['recipient_id'] as String?,
        groupId: j['group_id'] as String?,
        conversationType: j['conversation_type'] as String? ?? 'direct',
        content: j['content'] as String? ?? '',
        createdAt: DateTime.parse(j['created_at'] as String),
        readAt: j['read_at'] != null ? DateTime.tryParse(j['read_at'] as String) : null,
      );
}

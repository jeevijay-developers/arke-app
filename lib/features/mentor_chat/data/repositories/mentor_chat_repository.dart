import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/mentor_message.dart';
import '../models/mentor_info.dart';

class MentorChatRepository {
  final SupabaseClient _client;

  MentorChatRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  String? get _userId => _client.auth.currentUser?.id;

  Future<MentorInfo?> fetchAssignedMentor() async {
    try {
      final uid = _userId;
      if (uid == null) return null;
      final data = await _client
          .from('mentor_student_assignments')
          .select('mentor_id')
          .eq('student_id', uid)
          .isFilter('removed_at', null)
          .maybeSingle();
      if (data == null) return null;
      final mentorId = data['mentor_id'] as String;
      final profile = await _client
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('user_id', mentorId)
          .maybeSingle();
      return MentorInfo(
        mentorId: mentorId,
        name: profile?['full_name'] as String?,
        avatarUrl: profile?['avatar_url'] as String?,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<MentorMessage>> fetchDirectMessages(String mentorId) async {
    try {
      final uid = _userId;
      if (uid == null) return [];
      final data = await _client
          .from('mentor_messages')
          .select(
              'id, sender_id, recipient_id, group_id, conversation_type, content, created_at, read_at')
          .eq('conversation_type', 'direct')
          .or('and(sender_id.eq.$uid,recipient_id.eq.$mentorId),and(sender_id.eq.$mentorId,recipient_id.eq.$uid)')
          .eq('is_deleted', false)
          .order('created_at', ascending: true);
      return (data as List<dynamic>)
          .map((r) => MentorMessage.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<MentorMessage> sendDirectMessage({
    required String mentorId,
    required String content,
  }) async {
    try {
      final uid = _userId;
      if (uid == null) throw const UnauthorizedException();
      final inserted = await _client
          .from('mentor_messages')
          .insert({
            'sender_id': uid,
            'recipient_id': mentorId,
            'conversation_type': 'direct',
            'content': content,
            'is_deleted': false,
          })
          .select(
              'id, sender_id, recipient_id, group_id, conversation_type, content, created_at, read_at')
          .single();
      return MentorMessage.fromJson(inserted);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchMentorReviews(String mentorId) async {
    try {
      final data = await _client
          .from('mentor_reviews')
          .select('id, student_id, rating, review, created_at')
          .eq('mentor_id', mentorId)
          .order('created_at', ascending: false);
      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Map<String, dynamic>?> fetchMyReview(String mentorId) async {
    try {
      final uid = _userId;
      if (uid == null) return null;
      return await _client
          .from('mentor_reviews')
          .select('id, rating, review')
          .eq('mentor_id', mentorId)
          .eq('student_id', uid)
          .maybeSingle();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> submitRating({
    required String mentorId,
    required int rating,
    String? review,
  }) async {
    try {
      final uid = _userId;
      if (uid == null) throw const UnauthorizedException();
      final existing = await fetchMyReview(mentorId);
      if (existing != null) {
        await _client.from('mentor_reviews').update({
          'rating': rating,
          'review': review,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', existing['id'] as String);
      } else {
        await _client.from('mentor_reviews').insert({
          'mentor_id': mentorId,
          'student_id': uid,
          'rating': rating,
          'review': review,
        });
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> submitReport({
    required String mentorId,
    required String mentorName,
    required String category,
    required String subject,
    required String description,
    String? evidenceUrl,
  }) async {
    try {
      final uid = _userId;
      if (uid == null) throw const UnauthorizedException();
      await _client.from('reports').insert({
        'reporter_id': uid,
        'reported_user_id': mentorId,
        'reported_name': mentorName,
        'reported_role': 'mentor',
        'category': category,
        'subject': subject,
        'description': description,
        'evidence_url': evidenceUrl,
        'status': 'pending',
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Stream<List<MentorMessage>> messagesStream(String mentorId) {
    final uid = _userId;
    if (uid == null) return const Stream.empty();
    return _client
        .from('mentor_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((rows) => rows
            .where((r) =>
                r['is_deleted'] == false &&
                r['conversation_type'] == 'direct' &&
                ((r['sender_id'] == uid && r['recipient_id'] == mentorId) ||
                    (r['sender_id'] == mentorId && r['recipient_id'] == uid)))
            .map((r) => MentorMessage.fromJson(r))
            .toList());
  }
}

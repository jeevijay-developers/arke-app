import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/services/supabase_service.dart';
import '../models/doubt.dart';
import '../models/doubt_answer.dart';

class DoubtsRepository {
  final SupabaseClient _client;

  DoubtsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  Future<List<Doubt>> fetchMyDoubts() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await _client
          .from('doubts')
          .select(
            'id, user_id, subject, topic, question_text, image_url, status, '
            'ai_answer, routed_to, ai_escalated, resolution_type, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((r) => Doubt.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<DoubtAnswer>> fetchAnswersForDoubt(String doubtId) async {
    try {
      final data = await _client
          .from('doubt_answers')
          .select(
            'id, doubt_id, responder_id, responder_role, answer_text, '
            'image_url, helpful_count, created_at',
          )
          .eq('doubt_id', doubtId)
          .order('created_at', ascending: true);
      return (data as List<dynamic>)
          .map((r) => DoubtAnswer.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Doubt> submitDoubt({
    required String subject,
    required String questionText,
    required String routedTo,
    String? imageUrl,
    String? topic,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw const UnauthorizedException();
      final inserted = await _client
          .from('doubts')
          .insert({
            'user_id': userId,
            'subject': subject,
            'question_text': questionText,
            'routed_to': routedTo,
            'status': 'pending',
            'ai_escalated': false,
            'image_url': imageUrl,
            'topic': topic,
          })
          .select(
            'id, user_id, subject, topic, question_text, image_url, status, '
            'ai_answer, routed_to, ai_escalated, resolution_type, created_at',
          )
          .single();
      return Doubt.fromJson(inserted);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Doubt?> callAiSolver({
    required String doubtId,
    required String subject,
    required String question,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'ai-doubt-solver',
        body: {'doubtId': doubtId, 'subject': subject, 'question': question},
      );
      if (response.status != 200) {
        final msg = (response.data as Map<String, dynamic>?)?['error'] ??
            'AI solver error (${response.status})';
        throw ServerException(msg.toString());
      }
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = details is Map
          ? details['error']?.toString()
          : details is String
              ? details
              : null;
      throw ServerException(msg ?? 'AI solver unavailable');
    } catch (e) {
      throw AppException.from(e);
    }

    final updated = await _client
        .from('doubts')
        .select(
          'id, user_id, subject, topic, question_text, image_url, status, '
          'ai_answer, routed_to, ai_escalated, resolution_type, created_at',
        )
        .eq('id', doubtId)
        .single();
    return Doubt.fromJson(updated);
  }
}

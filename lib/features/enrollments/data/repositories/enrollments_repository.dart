import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/services/supabase_service.dart';
import '../models/enrollment.dart';

class EnrollmentsRepository {
  final SupabaseClient _client;

  EnrollmentsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  Future<void> enrollInCourse(String courseId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw const UnauthorizedException();
      await _client.from('enrollments').upsert({
        'user_id': userId,
        'course_id': courseId,
        'is_active': true,
        'progress_percent': 0,
        'completed_lessons': 0,
      }, onConflict: 'user_id,course_id');
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Enrollment>> fetchMyEnrollments() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];
      final data = await _client
          .from('enrollments')
          .select(
            'id, user_id, course_id, progress_percent, completed_lessons, '
            'last_lesson_title, last_accessed_at, is_active, created_at, '
            'courses(name, subject, thumbnail_url, educator_name, total_lessons)',
          )
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('last_accessed_at', ascending: false);
      return (data as List<dynamic>)
          .map((r) => Enrollment.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}

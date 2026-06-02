import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/services/supabase_service.dart';
import '../models/app_test.dart';

class TestsRepository {
  final SupabaseClient _client;

  TestsRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  Future<List<AppTest>> fetchPublished() async {
    try {
      final data = await _client
          .from('tests')
          .select(
            'id, title, description, test_type, exam_pattern, subjects, '
            'duration_minutes, total_marks, total_questions, visibility, '
            'starts_at, ends_at, course_id',
          )
          .eq('is_published', true)
          .order('created_at', ascending: false);
      return (data as List<dynamic>)
          .map((row) => AppTest.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/course.dart';

class CoursesRepository {
  final SupabaseClient _client;

  CoursesRepository({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  Future<List<Course>> fetchCourses() async {
    try {
      final data = await _client
          .from('courses')
          .select(
            'id, name, educator_name, subject, thumbnail_url, rating, price, '
            'description, level, badge, total_enrolled, total_lessons, duration_hours',
          )
          .eq('is_published', true)
          .order('name');
      return (data as List<dynamic>)
          .map((row) => Course.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}

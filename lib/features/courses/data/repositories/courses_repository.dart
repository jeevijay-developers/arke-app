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
            'id, name, internal_name, description, thumbnail_url, target, "class", '
            'language, mrp, sale_price, discount_percent, show_price_with_gst, '
            'is_course_free, max_usage_days, course_end_date, priority, badge, '
            'is_active, assigned_teacher_id, what_youll_learn, requirements',
          )
          .eq('is_active', true)
          .order('priority');
      return (data as List<dynamic>)
          .map((row) => Course.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}

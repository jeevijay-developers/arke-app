import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import 'models/app_test.dart';
import 'repositories/tests_repository.dart';

final testsRepositoryProvider = Provider<TestsRepository>((ref) {
  return TestsRepository();
});

final testsProvider = FutureProvider.autoDispose<List<AppTest>>((ref) async {
  final repo = ref.watch(testsRepositoryProvider);
  return repo.fetchPublished();
});

// Tests linked to a specific course via course_id column.
final courseTestsProvider =
    FutureProvider.autoDispose.family<List<AppTest>, String>((ref, courseId) async {
  final client = SupabaseService.client;
  final data = await client
      .from('tests')
      .select(
        'id, title, description, test_type, exam_pattern, subjects, '
        'duration_minutes, total_marks, total_questions, visibility, '
        'starts_at, ends_at, course_id',
      )
      .eq('course_id', courseId)
      .eq('is_published', true)
      .order('created_at', ascending: false);
  return (data as List<dynamic>)
      .map((r) => AppTest.fromJson(r as Map<String, dynamic>))
      .toList();
});

const _testSelect =
    'id, title, description, test_type, exam_pattern, subjects, '
    'duration_minutes, total_marks, total_questions, visibility, '
    'starts_at, ends_at, course_id';

/// Fetches only tests the student can access:
/// 1. Standalone tests (course_id IS NULL)
/// 2. Tests belonging to courses the student is enrolled in
final accessibleTestsProvider = FutureProvider.autoDispose<List<AppTest>>((ref) async {
  final client = SupabaseService.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  // Get enrolled course IDs
  final enrollments = await client
      .from('enrollments')
      .select('course_id')
      .eq('user_id', userId)
      .eq('is_active', true);

  final enrolledCourseIds = (enrollments as List)
      .map((e) => e['course_id'] as String)
      .where((id) => id.isNotEmpty)
      .toList();

  // Fetch all published tests in one query
  final allData = await client
      .from('tests')
      .select(_testSelect)
      .eq('is_published', true)
      .order('created_at', ascending: false);

  final allTests = (allData as List)
      .map((r) => AppTest.fromJson(r as Map<String, dynamic>))
      .toList();

  // Filter: standalone (course_id null) OR enrolled course
  final enrolledSet = enrolledCourseIds.toSet();
  return allTests.where((t) {
    if (t.courseId == null || t.courseId!.isEmpty) return true; // standalone
    return enrolledSet.contains(t.courseId);                    // enrolled course
  }).toList();
});

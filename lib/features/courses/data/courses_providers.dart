import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/config/env.dart';
import 'models/chapter.dart';
import 'models/course.dart';
import 'models/lesson.dart';
import 'repositories/courses_repository.dart';

// Resolves a stored video_url path to a playable URL.
// Absolute URLs are returned as-is.
// Relative paths are resolved against the external S3 video CDN first,
// then fall back to Supabase course-resources (signed URL).
// Returns null only when neither source can produce a URL.
Future<String?> resolveVideoUrl(String rawPath) async {
  if (rawPath.startsWith('http')) return rawPath;

  // 1. External S3 CDN — this is where the web app serves videos from
  final s3Base = Env.s3VideoBaseUrl;
  if (s3Base.isNotEmpty) {
    return '$s3Base/$rawPath';
  }

  // 2. Fallback: try Supabase course-resources signed URL
  try {
    final signed = await SupabaseService.client.storage
        .from('course-resources')
        .createSignedUrl(rawPath, 3600);
    return signed;
  } catch (_) {}

  return null;
}

class CourseReview {
  final String id;
  final String userId;
  final int rating;
  final String? review;
  final DateTime createdAt;
  const CourseReview({required this.id, required this.userId, required this.rating, this.review, required this.createdAt});
  factory CourseReview.fromJson(Map<String, dynamic> j) => CourseReview(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    rating: j['rating'] as int,
    review: j['review'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

class CoursePdf {
  final String id;
  final String title;
  final String fileUrl;
  final int? sizeBytes;
  const CoursePdf({required this.id, required this.title, required this.fileUrl, this.sizeBytes});
  factory CoursePdf.fromJson(Map<String, dynamic> j) => CoursePdf(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    fileUrl: j['file_url'] as String? ?? '',
    sizeBytes: (j['file_size_bytes'] ?? j['size_bytes']) as int?,
  );
}

final coursesRepositoryProvider = Provider<CoursesRepository>((ref) {
  return CoursesRepository();
});

final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
  final repo = ref.watch(coursesRepositoryProvider);
  return repo.fetchCourses();
});

final courseDetailProvider =
    FutureProvider.autoDispose.family<Course, String>((ref, id) async {
  final client = SupabaseService.client;
  final data = await client
      .from('courses')
      .select(
        'id, name, educator_name, subject, thumbnail_url, rating, price, '
        'description, level, badge, total_enrolled, total_lessons, duration_hours, '
        'what_youll_learn, requirements',
      )
      .eq('id', id)
      .single();
  return Course.fromJson(data);
});

final lessonsProvider =
    FutureProvider.autoDispose.family<List<Lesson>, String>((ref, courseId) async {
  final client = SupabaseService.client;
  final data = await client
      .from('lessons')
      .select('id, course_id, chapter_id, title, position, duration_seconds, video_url, is_free_preview, type')
      .eq('course_id', courseId)
      .order('position');
  return (data as List<dynamic>)
      .map((row) => Lesson.fromJson(row as Map<String, dynamic>))
      .toList();
});

final courseReviewsProvider =
    FutureProvider.autoDispose.family<List<CourseReview>, String>((ref, courseId) async {
  final client = SupabaseService.client;
  final data = await client
      .from('course_reviews')
      .select('id, user_id, rating, review, created_at')
      .eq('course_id', courseId)
      .order('created_at', ascending: false);
  return (data as List<dynamic>)
      .map((r) => CourseReview.fromJson(r as Map<String, dynamic>))
      .toList();
});

final coursePdfsProvider =
    FutureProvider.autoDispose.family<List<CoursePdf>, String>((ref, courseId) async {
  final client = SupabaseService.client;
  final data = await client
      .from('course_resources')
      .select('id, title, file_url, file_size_bytes')
      .eq('course_id', courseId)
      .eq('resource_type', 'pdf')
      .eq('is_published', true)
      .order('position');
  return (data as List<dynamic>)
      .map((r) => CoursePdf.fromJson(r as Map<String, dynamic>))
      .toList();
});

final chaptersProvider =
    FutureProvider.autoDispose.family<List<Chapter>, String>((ref, courseId) async {
  final client = SupabaseService.client;
  final data = await client
      .from('chapters')
      .select('id, course_id, title, position')
      .eq('course_id', courseId)
      .order('position');
  return (data as List<dynamic>)
      .map((r) => Chapter.fromJson(r as Map<String, dynamic>))
      .toList();
});

final lessonDetailProvider =
    FutureProvider.autoDispose.family<Lesson, String>((ref, lessonId) async {
  final client = SupabaseService.client;
  final data = await client
      .from('lessons')
      .select('id, course_id, chapter_id, title, position, duration_seconds, video_url, is_free_preview, type')
      .eq('id', lessonId)
      .single();
  return Lesson.fromJson(data);
});

// Enrolled count via RPC — bypasses RLS so all students are counted, not just the viewer's own row.
final courseEnrolledCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, courseId) async {
  final client = SupabaseService.client;
  final result = await client.rpc(
    'get_course_enrolled_count',
    params: {'p_course_id': courseId},
  );
  return (result as int?) ?? 0;
});

// The current user's existing review for a course, or null if none.
final myReviewProvider =
    FutureProvider.autoDispose.family<CourseReview?, String>((ref, courseId) async {
  final client = SupabaseService.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  final data = await client
      .from('course_reviews')
      .select('id, user_id, rating, review, created_at')
      .eq('course_id', courseId)
      .eq('user_id', userId)
      .maybeSingle();
  if (data == null) return null;
  return CourseReview.fromJson(data);
});

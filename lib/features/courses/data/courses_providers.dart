import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/config/env.dart';
import 'models/chapter.dart';
import 'models/content_item.dart';
import 'models/course.dart';
import 'models/folder.dart';
import 'models/lesson.dart';
import 'repositories/courses_repository.dart';

// ── Video URL resolution (unchanged) ──────────────────────────────────────
Future<String?> resolveVideoUrl(String rawPath) async {
  if (rawPath.startsWith('http')) return rawPath;
  final s3Base = Env.s3VideoBaseUrl;
  if (s3Base.isNotEmpty) return '$s3Base/$rawPath';
  try {
    return await SupabaseService.client.storage
        .from('course-resources')
        .createSignedUrl(rawPath, 3600);
  } catch (_) {}
  return null;
}

// ── Repository provider ────────────────────────────────────────────────────
final coursesRepositoryProvider = Provider<CoursesRepository>(
  (_) => CoursesRepository(),
);

// ── Course store list (Screen 1) ───────────────────────────────────────────
final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) =>
    ref.watch(coursesRepositoryProvider).fetchCourses());

// ── Single course detail by id ─────────────────────────────────────────────
final courseDetailProvider =
    FutureProvider.autoDispose.family<Course, String>((ref, id) async {
  final data = await SupabaseService.client
      .from('courses')
      .select(
        'id, name, internal_name, description, thumbnail_url, target, "class", '
        'language, mrp, sale_price, discount_percent, show_price_with_gst, '
        'is_course_free, max_usage_days, course_end_date, priority, badge, '
        'is_active, assigned_teacher_id, what_youll_learn, requirements',
      )
      .eq('id', id)
      .single();
  return Course.fromJson(data);
});

// ── Single course detail by slug ───────────────────────────────────────────
final courseBySlugProvider =
    FutureProvider.autoDispose.family<Course, String>((ref, slug) async {
  final data = await SupabaseService.client
      .from('courses')
      .select(
        'id, name, internal_name, description, thumbnail_url, target, "class", '
        'language, mrp, sale_price, discount_percent, show_price_with_gst, '
        'is_course_free, max_usage_days, course_end_date, priority, badge, '
        'is_active, assigned_teacher_id, what_youll_learn, requirements',
      )
      .eq('slug', slug)
      .single();
  return Course.fromJson(data);
});

// ── Level-2 folders for a course (parent_id is null) ──────────────────────
final courseFoldersProvider =
    FutureProvider.autoDispose.family<List<CourseFolder>, String>(
        (ref, courseId) async {
  final data = await SupabaseService.client
      .from('folders')
      .select('id, course_id, parent_id, name, "order"')
      .eq('course_id', courseId)
      .isFilter('parent_id', null)
      .order('order');
  return (data as List<dynamic>)
      .map((r) => CourseFolder.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Sub-folders (level 3) for a given folder ──────────────────────────────
final subFoldersProvider =
    FutureProvider.autoDispose.family<List<CourseFolder>, String>(
        (ref, folderId) async {
  final data = await SupabaseService.client
      .from('folders')
      .select('id, course_id, parent_id, name, "order"')
      .eq('parent_id', folderId)
      .order('order');
  return (data as List<dynamic>)
      .map((r) => CourseFolder.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Content items for a folder ─────────────────────────────────────────────
final contentItemsProvider =
    FutureProvider.autoDispose.family<List<ContentItem>, String>(
        (ref, folderId) async {
  final data = await SupabaseService.client
      .from('content_items')
      .select(
        'id, course_id, folder_id, type, title, description, '
        'file_url, video_url, video_source, zoom_link, scheduled_at, '
        'test_id, "order", is_free_preview',
      )
      .eq('folder_id', folderId)
      .order('order');
  return (data as List<dynamic>)
      .map((r) => ContentItem.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Enrollment with enrolled_at (for free-course expiry check) ────────────
class EnrollmentInfo {
  final String courseId;
  final DateTime enrolledAt;
  const EnrollmentInfo({required this.courseId, required this.enrolledAt});
}

final enrollmentInfoProvider =
    FutureProvider.autoDispose.family<EnrollmentInfo?, String>(
        (ref, courseId) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return null;
  final data = await SupabaseService.client
      .from('enrollments')
      .select('course_id, created_at')
      .eq('user_id', userId)
      .eq('course_id', courseId)
      .maybeSingle();
  if (data == null) return null;
  return EnrollmentInfo(
    courseId: data['course_id'] as String,
    enrolledAt: DateTime.parse(data['created_at'] as String),
  );
});

// ── Legacy models ──────────────────────────────────────────────────────────
class CourseReview {
  final String id;
  final int rating;
  final String? review;
  final DateTime createdAt;
  const CourseReview({
    required this.id,
    required this.rating,
    this.review,
    required this.createdAt,
  });
  factory CourseReview.fromJson(Map<String, dynamic> j) => CourseReview(
        id: j['id'] as String,
        rating: (j['rating'] as num).toInt(),
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
        title: j['title'] as String? ?? 'PDF',
        fileUrl: j['file_url'] as String? ?? j['fileUrl'] as String? ?? '',
        sizeBytes: j['size_bytes'] as int?,
      );
}

// ── Legacy providers (used by course_detail_screen / course_player_screen) ─
final lessonsProvider =
    FutureProvider.autoDispose.family<List<Lesson>, String>((ref, courseId) async {
  final data = await SupabaseService.client
      .from('lessons')
      .select('id, chapter_id, course_id, title, video_url, duration_seconds, '
          'position, is_free_preview, type')
      .eq('course_id', courseId)
      .order('position');
  return (data as List<dynamic>)
      .map((r) => Lesson.fromJson(r as Map<String, dynamic>))
      .toList();
});

final chaptersProvider =
    FutureProvider.autoDispose.family<List<Chapter>, String>((ref, courseId) async {
  final data = await SupabaseService.client
      .from('chapters')
      .select('id, course_id, title, position')
      .eq('course_id', courseId)
      .order('position');
  return (data as List<dynamic>)
      .map((r) => Chapter.fromJson(r as Map<String, dynamic>))
      .toList();
});

final courseReviewsProvider =
    FutureProvider.autoDispose.family<List<CourseReview>, String>(
        (ref, courseId) async {
  final data = await SupabaseService.client
      .from('course_reviews')
      .select('id, rating, review, created_at')
      .eq('course_id', courseId)
      .order('created_at', ascending: false);
  return (data as List<dynamic>)
      .map((r) => CourseReview.fromJson(r as Map<String, dynamic>))
      .toList();
});

final myReviewProvider =
    FutureProvider.autoDispose.family<CourseReview?, String>(
        (ref, courseId) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return null;
  final data = await SupabaseService.client
      .from('course_reviews')
      .select('id, rating, review, created_at')
      .eq('course_id', courseId)
      .eq('user_id', userId)
      .maybeSingle();
  if (data == null) return null;
  return CourseReview.fromJson(data);
});

final coursePdfsProvider =
    FutureProvider.autoDispose.family<List<CoursePdf>, String>(
        (ref, courseId) async {
  final data = await SupabaseService.client
      .from('course_pdfs')
      .select('id, title, file_url, size_bytes')
      .eq('course_id', courseId)
      .order('position');
  return (data as List<dynamic>)
      .map((r) => CoursePdf.fromJson(r as Map<String, dynamic>))
      .toList();
});

final courseEnrolledCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, courseId) async {
  final data = await SupabaseService.client
      .from('enrollments')
      .select('id')
      .eq('course_id', courseId)
      .eq('is_active', true);
  return (data as List<dynamic>).length;
});

final isEnrolledProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, courseId) async {
  final userId = SupabaseService.client.auth.currentUser?.id;
  if (userId == null) return false;
  final data = await SupabaseService.client
      .from('enrollments')
      .select('id')
      .eq('user_id', userId)
      .eq('course_id', courseId)
      .maybeSingle();
  return data != null;
});

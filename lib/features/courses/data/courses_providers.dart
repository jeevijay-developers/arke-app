import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/config/env.dart';
import 'models/content_item.dart';
import 'models/course.dart';
import 'models/folder.dart';
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
        'is_active, is_featured, tags, rating, '
        'assigned_teacher_id, what_youll_learn, requirements',
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
        'is_active, is_featured, tags, rating, '
        'assigned_teacher_id, what_youll_learn, requirements',
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
      .select('id, course_id, parent_id, name, "order", created_at')
      .eq('course_id', courseId)
      .isFilter('parent_id', null)
      .order('order', ascending: true)
      .order('created_at', ascending: true);
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
      .select('id, course_id, parent_id, name, "order", created_at')
      .eq('parent_id', folderId)
      .order('order', ascending: true)
      .order('created_at', ascending: true);
  return (data as List<dynamic>)
      .map((r) => CourseFolder.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Video/recorded_lecture items (Lectures tab) ────────────────────────────
// Always returns only admin-marked free-preview items regardless of enrollment.
// Enrolled users access all content through the course home → folder view flow.
final freePreviewItemsProvider =
    FutureProvider.autoDispose.family<List<ContentItem>, String>(
        (ref, courseId) async {
  final data = await SupabaseService.client
      .from('content_items')
      .select(
        'id, course_id, folder_id, type, title, description, '
        'file_url, video_url, video_source, zoom_link, scheduled_at, '
        'test_id, "order", is_free_preview',
      )
      .eq('course_id', courseId)
      .inFilter('type', ['video', 'recorded_lecture'])
      .eq('is_free_preview', true)
      .order('order');
  return (data as List<dynamic>)
      .map((r) => ContentItem.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── All PDF content items for a course (PDFs tab) ─────────────────────────
final coursePdfItemsProvider =
    FutureProvider.autoDispose.family<List<ContentItem>, String>(
        (ref, courseId) async {
  final data = await SupabaseService.client
      .from('content_items')
      .select(
        'id, course_id, folder_id, type, title, description, '
        'file_url, video_url, video_source, zoom_link, scheduled_at, '
        'test_id, "order", is_free_preview',
      )
      .eq('course_id', courseId)
      .eq('type', 'pdf')
      .order('order');
  return (data as List<dynamic>)
      .map((r) => ContentItem.fromJson(r as Map<String, dynamic>))
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

// ── Reviews ────────────────────────────────────────────────────────────────
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
      .eq('is_active', true)
      .maybeSingle();
  return data != null;
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/live_class.dart';

const _liveSelect =
    'id, title, subject, educator_name, educator_avatar, '
    'starts_at, ends_at, meeting_url, status, description, recording_url, course_id, slug';

/// Fetches only classes the student can access:
/// 1. Standalone classes (course_id IS NULL)
/// 2. Classes belonging to courses the student is enrolled in
final accessibleLiveClassesProvider = FutureProvider.autoDispose<List<LiveClass>>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return [];

  // Get enrolled course IDs
  final enrollments = await client
      .from('enrollments')
      .select('course_id')
      .eq('user_id', userId)
      .eq('is_active', true);

  final enrolledSet = (enrollments as List)
      .map((e) => e['course_id'] as String)
      .where((id) => id.isNotEmpty)
      .toSet();

  // Fetch all non-cancelled classes
  final allData = await client
      .from('live_classes')
      .select(_liveSelect)
      .not('status', 'eq', 'cancelled')
      .order('starts_at');

  final allClasses = (allData as List)
      .map((r) => LiveClass.fromJson(r as Map<String, dynamic>))
      .toList();

  // Filter: standalone (course_id null) OR enrolled course
  return allClasses.where((lc) {
    if (lc.courseId == null || lc.courseId!.isEmpty) return true;
    return enrolledSet.contains(lc.courseId);
  }).toList();
});

// Keep old provider for backwards compat (room screen uses liveClassByIdProvider)
final liveClassesProvider = FutureProvider.autoDispose<List<LiveClass>>((ref) async {
  final data = await Supabase.instance.client
      .from('live_classes')
      .select(_liveSelect)
      .not('status', 'eq', 'cancelled')
      .order('starts_at');
  return (data as List)
      .map((r) => LiveClass.fromJson(r as Map<String, dynamic>))
      .toList();
});

// Single live class by id — used by the room screen
final liveClassByIdProvider =
    FutureProvider.autoDispose.family<LiveClass?, String>((ref, id) async {
  final data = await Supabase.instance.client
      .from('live_classes')
      .select(_liveSelect)
      .eq('id', id)
      .single();
  return LiveClass.fromJson(data);
});

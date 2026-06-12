import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import 'data/courses_providers.dart';
import 'data/models/course.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
abstract class _C {
  static const primary  = Color(0xFFF97315);
  static const enroll   = Color(0xFF5B4BF5);
  static const free     = Color(0xFF10B981);
  static const featured = Color(0xFFF59E0B);
  static const textSub  = Color(0xFF64748B);
  static const surface  = Color(0xFFFFFFFF);
  static const bg       = Color(0xFFFFFBF8);
  static const border   = Color(0xFFE5E7EB);
  static const chip     = Color(0xFFFFF0E6);
}

// ── Screen ─────────────────────────────────────────────────────────────────
class CoursesListScreen extends ConsumerStatefulWidget {
  const CoursesListScreen({super.key});

  @override
  ConsumerState<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends ConsumerState<CoursesListScreen> {
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim().toLowerCase());
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() => _query = '');
  }

  // Filter by the student's exam, then apply the search query.
  List<Course> _applyFilters(List<Course> all, String exam, String userClass) {
    List<Course> list;
    if (exam.isEmpty) {
      list = all;
    } else if (exam == 'Foundation') {
      list = all.where((c) {
        if (c.target != 'Foundation') return false;
        if (userClass.isEmpty) return true;
        final cls = userClass.replaceAll('th', '').replaceAll('st', '').replaceAll('nd', '').replaceAll('rd', '');
        return c.courseClass == cls;
      }).toList();
    } else {
      list = all.where((c) => c.target == exam).toList();
    }

    if (_query.isEmpty) return list;

    return list.where((c) {
      return c.name.toLowerCase().contains(_query) ||
          c.target.toLowerCase().contains(_query) ||
          c.courseClass.toLowerCase().contains(_query) ||
          (c.internalName?.toLowerCase().contains(_query) ?? false) ||
          (c.teacherName?.toLowerCase().contains(_query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async     = ref.watch(coursesProvider);
    final profile   = ref.watch(profileSetupInfoProvider);
    final exam      = profile.exam;
    final userClass = profile.userClass;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        title: const Text(
          'Courses',
          style: TextStyle(
            color     : Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize  : 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: _C.surface,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller     : _searchCtrl,
              focusNode      : _searchFocus,
              onChanged      : _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
              decoration: InputDecoration(
                hintText : 'Search by name, exam, class…',
                hintStyle: const TextStyle(color: _C.textSub, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _C.textSub,
                  size: 20,
                ),
                suffixIcon: _query.isNotEmpty
                    ? GestureDetector(
                        onTap : _clearSearch,
                        child : const Icon(
                          Icons.close_rounded,
                          color: _C.textSub,
                          size : 18,
                        ),
                      )
                    : null,
                filled    : true,
                fillColor : _C.bg,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical  : 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide  : const BorderSide(color: _C.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide  : const BorderSide(color: _C.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide  : const BorderSide(color: _C.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _C.primary)),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(color: _C.textSub)),
        ),
        data: (courses) {
          final filtered = _applyFilters(courses, exam, userClass);

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    size : 48,
                    color: _C.textSub,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _query.isNotEmpty
                        ? 'No courses found for "$_query"'
                        : 'No courses available.',
                    style    : const TextStyle(color: _C.textSub, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  if (_query.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _clearSearch,
                      child: const Text(
                        'Clear search',
                        style: TextStyle(color: _C.primary),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            color    : _C.primary,
            onRefresh: () => ref.refresh(coursesProvider.future),
            child: ListView.separated(
              padding         : const EdgeInsets.all(16),
              itemCount       : filtered.length,
              separatorBuilder: (_, i) => const SizedBox(height: 12),
              itemBuilder     : (_, i) => _CourseCard(course: filtered[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Course card ────────────────────────────────────────────────────────────
class _CourseCard extends ConsumerWidget {
  final Course course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrolled    = ref.watch(isEnrolledProvider(course.id)).valueOrNull ?? false;
    final hasThumbnail =
        course.thumbnailUrl != null && course.thumbnailUrl!.isNotEmpty;

    return GestureDetector(
      onTap: () => context.push('/course/${course.id}'),
      child: Container(
        decoration: BoxDecoration(
          color       : _C.surface,
          borderRadius: BorderRadius.circular(16),
          border      : Border.all(color: _C.border),
          boxShadow   : [
            BoxShadow(
              color     : Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset    : const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ────────────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: hasThumbnail
                  ? CachedNetworkImage(
                      imageUrl   : course.thumbnailUrl!,
                      width      : double.infinity,
                      height     : 180,
                      fit        : BoxFit.cover,
                      errorWidget: (ctx, url, err) => _PlaceholderThumb(),
                    )
                  : _PlaceholderThumb(),
            ),

            // ── Info ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge chips
                  Wrap(
                    spacing    : 6,
                    runSpacing : 4,
                    children   : [
                      _Badge('Class ${course.courseClass}', color: _C.enroll),
                      _Badge(course.target, color: _C.primary),
                      if (course.isCourseFree)
                        _Badge('Free', color: _C.free),
                      if (course.isFeatured)
                        _Badge('Featured', color: _C.featured),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Course name
                  Text(
                    course.name,
                    maxLines : 2,
                    overflow : TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize  : 16,
                      fontWeight: FontWeight.w800,
                      color     : Color(0xFF111827),
                      height    : 1.3,
                    ),
                  ),

                  if (course.teacherName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      course.teacherName!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color   : _C.textSub,
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // CTA button
                  SizedBox(
                    width : double.infinity,
                    height: 44,
                    child: enrolled
                        ? ElevatedButton(
                            onPressed: () =>
                                context.push('/my-courses/${course.id}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _C.free,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Continue Learning',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize  : 14,
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () =>
                                context.push('/course/${course.id}'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: course.isCourseFree
                                  ? _C.free
                                  : _C.enroll,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Enroll Now',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize  : 14,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width : double.infinity,
    height: 180,
    color : _C.chip,
    child : const Icon(Icons.school_rounded, color: _C.primary, size: 48),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final Color  color;
  const _Badge(this.label, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color       : color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(6),
      border      : Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize  : 10.5,
        fontWeight: FontWeight.w700,
        color     : color,
      ),
    ),
  );
}

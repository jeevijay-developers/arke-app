import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'data/courses_providers.dart';
import 'data/models/course.dart';
import 'data/models/folder.dart';
import 'widgets/folder_tile.dart';

abstract class _C {
  static const primary   = Color(0xFFF97315);
  static const textSub   = Color(0xFF64748B);
  static const surface   = Color(0xFFFFFFFF);
  static const bg        = Color(0xFFFFFBF8);
  static const warning   = Color(0xFFF59E0B);
  static const warnBg    = Color(0xFFFFFBEB);
}

// ── Screen 3 — Course Home (post-purchase, folder grid) ───────────────────
class CourseHomeScreen extends ConsumerWidget {
  final String courseId;
  const CourseHomeScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));
    final foldersAsync = ref.watch(courseFoldersProvider(courseId));

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
        title: courseAsync.maybeWhen(
          data: (c) => Text(
            c.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827)),
          ),
          orElse: () => const Text('Course'),
        ),
      ),
      body: foldersAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _C.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (folders) => _Body(
          courseId: courseId,
          folders: folders,
          course: courseAsync.valueOrNull,
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final String courseId;
  final List<CourseFolder> folders;
  final Course? course;
  const _Body(
      {required this.courseId, required this.folders, required this.course});

  bool get _showExpiryWarning {
    if (course == null || course!.courseEndDate == null) return false;
    final daysLeft =
        course!.courseEndDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 7;
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        if (_showExpiryWarning)
          SliverToBoxAdapter(
            child: _ExpiryBanner(endDate: course!.courseEndDate!),
          ),
        if (folders.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text('No content yet.',
                  style: TextStyle(color: _C.textSub)),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => FolderTile(
                  folder: folders[i],
                  onTap: () => context.push(
                      '/my-courses/$courseId/folder/${folders[i].id}',
                      extra: folders[i].name),
                ),
                childCount: folders.length,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Expiry warning banner ──────────────────────────────────────────────────
class _ExpiryBanner extends StatelessWidget {
  final DateTime endDate;
  const _ExpiryBanner({required this.endDate});

  @override
  Widget build(BuildContext context) {
    final days = endDate.difference(DateTime.now()).inDays;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.warnBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _C.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: _C.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Course access expires in $days day${days == 1 ? '' : 's'}.',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }
}


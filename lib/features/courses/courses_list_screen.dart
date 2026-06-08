import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'data/courses_providers.dart';
import 'data/models/course.dart';

// ── Design tokens ──────────────────────────────────────────────────────────
abstract class _C {
  static const primary = Color(0xFFF97315);
  static const enroll  = Color(0xFF5B4BF5);
  static const free    = Color(0xFF10B981);
  static const textSub = Color(0xFF64748B);
  static const surface = Color(0xFFFFFFFF);
  static const bg      = Color(0xFFFFFBF8);
  static const border  = Color(0xFFE5E7EB);
  static const chip    = Color(0xFFFFF0E6);
}

const _kTargets = ['All', 'JEE', 'NEET', 'Foundation'];

// ── Screen ─────────────────────────────────────────────────────────────────
class CoursesListScreen extends ConsumerStatefulWidget {
  const CoursesListScreen({super.key});

  @override
  ConsumerState<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends ConsumerState<CoursesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _kTargets.length, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(coursesProvider);
    final selected = _kTargets[_tab.index];

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.surface,
        elevation: 0,
        title: const Text(
          'Courses',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: _C.surface,
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: _C.primary,
              unselectedLabelColor: _C.textSub,
              indicatorColor: _C.primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
              tabs: _kTargets.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _C.primary)),
        error: (e, _) => Center(
          child: Text('Error: $e',
              style: const TextStyle(color: _C.textSub)),
        ),
        data: (courses) {
          final filtered = selected == 'All'
              ? courses
              : courses.where((c) => c.target == selected).toList();

          if (filtered.isEmpty) {
            return const Center(
              child: Text('No courses available.',
                  style: TextStyle(color: _C.textSub)),
            );
          }

          return RefreshIndicator(
            color: _C.primary,
            onRefresh: () => ref.refresh(coursesProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _CourseCard(course: filtered[i]),
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
    final enrolled = ref.watch(isEnrolledProvider(course.id)).valueOrNull ?? false;

    return GestureDetector(
      onTap: () => context.push('/course/${course.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(14)),
              child: (course.thumbnailUrl != null && course.thumbnailUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: course.thumbnailUrl!,
                    width: 100,
                    height: 110,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 100,
                      height: 110,
                      color: _C.chip,
                      child: const Icon(Icons.school_rounded,
                          color: _C.primary, size: 32),
                    ),
                  )
                : Container(
                    width: 100,
                    height: 110,
                    color: _C.chip,
                    child: const Icon(Icons.school_rounded,
                        color: _C.primary, size: 32),
                  ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class + Target badges
                    Row(
                      children: [
                        _Badge('Class ${course.courseClass}',
                            color: _C.enroll),
                        const SizedBox(width: 6),
                        _Badge(course.target, color: _C.primary),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      course.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        height: 1.3,
                      ),
                    ),
                    if (course.teacherName != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        course.teacherName!,
                        style: const TextStyle(
                            fontSize: 12, color: _C.textSub),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _PriceWidget(course: course)),
                        const SizedBox(width: 8),
                        enrolled
                            ? _SmallButton(
                                label: 'Continue',
                                color: _C.free,
                                onTap: () => context
                                    .push('/my-courses/${course.id}'),
                              )
                            : _SmallButton(
                                label: 'Enroll',
                                color: _C.enroll,
                                onTap: () =>
                                    context.push('/course/${course.id}'),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

// ── Price widget ───────────────────────────────────────────────────────────
class _PriceWidget extends StatelessWidget {
  final Course course;
  const _PriceWidget({required this.course});

  @override
  Widget build(BuildContext context) {
    if (course.isCourseFree) {
      return const Text('Free',
          style: TextStyle(
              color: _C.free, fontWeight: FontWeight.w800, fontSize: 14));
    }

    final price = course.displayPrice;
    final suffix = course.showPriceWithGst ? ' (incl. GST)' : '';

    if (course.hasDiscount) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('₹${price.toStringAsFixed(0)}$suffix',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: Color(0xFF111827))),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${course.discountPercent.toStringAsFixed(0)}% off',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _C.free),
                ),
              ),
            ],
          ),
          Text(
            '₹${course.mrp.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 11,
                color: _C.textSub,
                decoration: TextDecoration.lineThrough),
          ),
        ],
      );
    }

    return Text('₹${price.toStringAsFixed(0)}$suffix',
        style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Color(0xFF111827)));
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}

class _SmallButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SmallButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(8)),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ),
      );
}

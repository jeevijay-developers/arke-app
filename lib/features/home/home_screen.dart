import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../skeleton_loading/home_skeleton.dart';
import '../../core/widgets/async_value_widget.dart';
import '../courses/data/courses_providers.dart';
import '../courses/data/models/course.dart';
import '../live/data/live_providers.dart';
import '../live/data/models/live_class.dart';
import '../enrollments/data/enrollments_providers.dart';
import '../enrollments/data/models/enrollment.dart';

abstract class DS {
  static const primary = Color(0xFFF97315);
  static const primaryLight = Color(0xFFFFF0E6);
  static const primaryDark = Color(0xFFE05A00);

  static const background = Color(0xFFFFFBF8);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);
  static const border = Color(0xFFE5E7EB);

  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);

  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveAsync = ref.watch(accessibleLiveClassesProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final enrollmentsAsync = ref.watch(enrollmentsProvider);
    final showSkeleton =
        liveAsync.isLoading &&
        coursesAsync.isLoading &&
        enrollmentsAsync.isLoading;

    return ColoredBox(
      color: DS.background,
      child: showSkeleton
          ? const HomeSkeleton()
          : RefreshIndicator(
              color: DS.primary,
              onRefresh: () async {
                ref.invalidate(accessibleLiveClassesProvider);
                ref.invalidate(coursesProvider);
                ref.invalidate(enrollmentsProvider);
                await Future.wait([
                  ref.read(accessibleLiveClassesProvider.future),
                  ref.read(coursesProvider.future),
                  ref.read(enrollmentsProvider.future),
                ]);
              },
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Recent Course Activity ──
                  const SizedBox(height: DS.s20),
                  _SectionHeader(
                    title: 'Recent Course Activity',
                    icon: Icons.history_edu_rounded,
                    color: DS.primary,
                  ),
                  const SizedBox(height: DS.s12),
                  AsyncValueWidget(
                    value: enrollmentsAsync,
                    loadingWidget: const SizedBox.shrink(),
                    isEmpty: (e) => e.isEmpty,
                    emptyMessage: 'You have not enrolled in any course yet.',
                    emptyIcon: Icons.school_outlined,
                    data: (enrollments) {
                      final last = enrollments.first;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DS.s16,
                          0,
                          DS.s16,
                          0,
                        ),
                        child: _ContinueCard(
                          enrollment: last,
                          onResume: () =>
                              context.push('/course-player/${last.courseId}'),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: DS.s24),

                  // ── Upcoming live classes ──
                  _SectionHeader(
                    title: 'Upcoming Live Classes',
                    icon: Icons.sensors_rounded,
                    color: DS.error,
                    actionLabel: 'See all',
                    onAction: () => context.push('/live'),
                  ),
                  const SizedBox(height: DS.s12),
                  SizedBox(
                    height: 178,
                    child: AsyncValueWidget(
                      value: liveAsync,
                      isEmpty: (classes) =>
                          classes.where((c) => !c.isPast).isEmpty,
                      emptyMessage: 'No upcoming classes',
                      emptyIcon: Icons.sensors_off_rounded,
                      errorPadding: const EdgeInsets.symmetric(horizontal: 16),
                      data: (classes) {
                        final upcoming = classes
                            .where((c) => !c.isPast)
                            .toList();
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DS.s16,
                          ),
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          itemCount: upcoming.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: DS.s12),
                          itemBuilder: (_, i) {
                            final lc = upcoming[i];
                            return _LiveCard(
                              live: lc,
                              onTap: () => context.push('/live/${lc.id}'),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: DS.s24),

                  // ── Recommended courses ──
                  _SectionHeader(
                    title: 'Recommended Courses',
                    icon: Icons.menu_book_rounded,
                    color: const Color(0xFF6366F1),
                    actionLabel: 'See all',
                    onAction: () => context.go('/courses'),
                  ),
                  const SizedBox(height: DS.s12),
                  AsyncValueWidget(
                    value: coursesAsync,
                    isEmpty: (courses) => courses.isEmpty,
                    emptyMessage: 'No courses available yet.',
                    emptyIcon: Icons.menu_book_outlined,
                    data: (courses) {
                      final featured = courses.take(4).toList();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: DS.s16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: featured.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.72,
                                crossAxisSpacing: DS.s12,
                                mainAxisSpacing: DS.s12,
                              ),
                          itemBuilder: (_, i) {
                            final c = featured[i];
                            return _CourseTile(
                              course: c,
                              onTap: () => context.push('/course/${c.id}'),
                            );
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: DS.s32),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: DS.s10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s10,
                  vertical: DS.s4,
                ),
                decoration: BoxDecoration(
                  color: DS.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: DS.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final Enrollment enrollment;
  final VoidCallback onResume;
  const _ContinueCard({required this.enrollment, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final thumb = enrollment.courseThumbnailUrl ?? '';
    final pct = enrollment.progressPercent;
    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusLg),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DS.s16, DS.s14, DS.s16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s4,
                  ),
                  decoration: BoxDecoration(
                    color: DS.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 12,
                        color: DS.primary,
                      ),
                      SizedBox(width: DS.s4),
                      Text(
                        'Continue Learning',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: DS.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '$pct% complete',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: DS.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DS.s12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DS.s16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  child: thumb.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          width: 88,
                          height: 66,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Container(
                            width: 88,
                            height: 66,
                            color: DS.surfaceVariant,
                          ),
                        )
                      : Container(
                          width: 88,
                          height: 66,
                          color: DS.surfaceVariant,
                          child: const Icon(Icons.menu_book, color: DS.primary),
                        ),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enrollment.courseTitle ?? 'Course',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: DS.textPrimary,
                          letterSpacing: -0.2,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (enrollment.courseSubject != null) ...[
                        const SizedBox(height: DS.s4),
                        Text(
                          enrollment.courseSubject!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: DS.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: DS.s14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DS.s16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: enrollment.progressFraction,
                minHeight: 5,
                backgroundColor: DS.border,
                color: DS.primary,
              ),
            ),
          ),
          const SizedBox(height: DS.s14),
          Padding(
            padding: const EdgeInsets.fromLTRB(DS.s16, 0, DS.s16, DS.s16),
            child: SizedBox(
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8C38), DS.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: DS.primary.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: onResume,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text(
                    'Resume',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  final LiveClass live;
  final VoidCallback onTap;
  const _LiveCard({required this.live, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLive = live.isLive;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          border: Border.all(
            color: isLive ? DS.error.withValues(alpha: 0.25) : DS.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isLive ? DS.error : Colors.black).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(DS.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusBadge(isLive: isLive),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s4,
                  ),
                  decoration: BoxDecoration(
                    color: DS.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: DS.border, width: 1),
                  ),
                  child: Text(
                    live.subject,
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DS.s10),
            Text(
              live.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: DS.textPrimary,
                letterSpacing: -0.2,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DS.s6),
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: DS.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 12,
                    color: DS.primary,
                  ),
                ),
                const SizedBox(width: DS.s6),
                Expanded(
                  child: Text(
                    live.educatorName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: DS.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Divider(color: DS.border, height: DS.s16, thickness: 1),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: isLive ? DS.error : DS.textSecondary,
                ),
                const SizedBox(width: DS.s4),
                Text(
                  _fmt(live.startsAt),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isLive ? DS.error : DS.textSecondary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s4,
                  ),
                  decoration: BoxDecoration(
                    color: isLive
                        ? DS.error.withValues(alpha: 0.08)
                        : DS.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isLive ? 'Join Now' : 'Set Reminder',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isLive ? DS.error : DS.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final diff = d.difference(DateTime.now());
    if (diff.inMinutes.abs() < 60) {
      return diff.isNegative
          ? 'Started ${-diff.inMinutes}m ago'
          : 'In ${diff.inMinutes} min';
    }
    if (diff.inHours.abs() < 24) return 'In ${diff.inHours} hr';
    return '${d.day}/${d.month}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isLive;
  const _StatusBadge({required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s4),
      decoration: BoxDecoration(
        color: isLive ? DS.error : DS.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DS.s4),
          ],
          Text(
            isLive ? 'LIVE' : 'Upcoming',
            style: TextStyle(
              color: isLive ? Colors.white : DS.primary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  const _CourseTile({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusLg),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DS.radiusLg),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: course.thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: DS.surfaceVariant),
                    ),
                    if (course.isFree)
                      Positioned(
                        top: DS.s8,
                        left: DS.s8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DS.s8,
                            vertical: DS.s4,
                          ),
                          decoration: BoxDecoration(
                            color: DS.success,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DS.s10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: DS.textPrimary,
                        letterSpacing: -0.1,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: DS.s4),
                    Text(
                      course.educator,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: DS.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 13,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: DS.s4),
                        Text(
                          course.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: DS.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          course.isFree
                              ? 'Free'
                              : '₹${course.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: DS.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

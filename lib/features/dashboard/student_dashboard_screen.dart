import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/providers.dart';
import 'widgets/dashboard_drawer.dart';
import '../auth/data/auth_repository.dart';
import '../live/data/live_providers.dart';
import '../live/data/models/live_class.dart';
import '../courses/data/courses_providers.dart';
import '../courses/data/models/course.dart';
import '../tests/data/tests_providers.dart';
import '../enrollments/data/enrollments_providers.dart';
import '../enrollments/data/models/enrollment.dart';
import '../profile/data/profile_providers.dart';

class _DashboardStats {
  final int testsAttempted;
  const _DashboardStats({required this.testsAttempted});
}

final _dashboardStatsProvider = FutureProvider.autoDispose<_DashboardStats>((ref) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const _DashboardStats(testsAttempted: 0);
  final data = await client
      .from('test_attempts')
      .select('id')
      .eq('user_id', userId);
  return _DashboardStats(testsAttempted: (data as List).length);
});

// ─────────────────────────────────────────────
// 💡 Move DS to lib/core/theme/design_system.dart
// ─────────────────────────────────────────────
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
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFFEEF2FF);
  static const teal = Color(0xFF14B8A6);
  static const tealLight = Color(0xFFF0FDFA);
  static const purple = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF06B6D4);

  static const double s2 = 2;
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

// ─────────────────────────────────────────────
// STUDENT DASHBOARD SCREEN
// ─────────────────────────────────────────────
class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser();
    final prefs = ref.read(prefsProvider);
    final region = ref.watch(regionProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final liveAsync = ref.watch(liveClassesProvider);
    final enrollmentsAsync = ref.watch(enrollmentsProvider);
    final coursesAsync = ref.watch(coursesProvider);
    final testsAsync = ref.watch(testsProvider);

    // Prefer profiles table (always up-to-date after edit) over auth metadata
    final name = profile?.fullName?.isNotEmpty == true
        ? profile!.fullName!
        : (user?.name ?? 'Learner');
    // Prefer target_exam from Supabase profile; fall back to legacy SharedPrefs
    final goal = profile?.targetExam ?? prefs.goal;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        endDrawer: const DashboardDrawer(),
        appBar: _DashboardAppBar(name: name),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(DS.s16, DS.s12, DS.s16, DS.s32),
          children: [
            // ── Greeting hero card ──
            _GreetingCard(
              name: name,
              goal: goal,
              region: region,
            ),
            const SizedBox(height: DS.s20),

            // ── Stats grid ──
            _StatsGrid(enrollmentsAsync: enrollmentsAsync),
            const SizedBox(height: DS.s24),

            // ── Continue learning ──
            enrollmentsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (enr) {
                if (enr.isEmpty) return const SizedBox.shrink();
                final last = enr.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeader(title: 'Continue Learning'),
                    const SizedBox(height: DS.s12),
                    _ContinueCard(
                      enrollment: last,
                      onResume: () =>
                          context.push('/course-player/${last.courseId}'),
                    ),
                    const SizedBox(height: DS.s24),
                  ],
                );
              },
            ),

            // ── Today's live classes ──
            _SectionHeader(
              title: "Today's Live Classes",
              actionLabel: 'See all',
              onAction: () => context.push('/live'),
            ),
            const SizedBox(height: DS.s12),
            SizedBox(
              height: 172,
              child: liveAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: DS.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (_, __) =>
                    _InlineError(message: 'Failed to load classes'),
                data: (classes) {
                  final today = classes.where((c) => !c.isPast).toList();
                  if (today.isEmpty) {
                    return _InlineEmpty(
                      icon: Icons.sensors_outlined,
                      message: 'No classes today',
                    );
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: today.length,
                    separatorBuilder: (_, __) => const SizedBox(width: DS.s12),
                    itemBuilder: (_, i) => _LiveTile(
                      live: today[i],
                      onTap: () => context.push('/live/${today[i].id}'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: DS.s24),

            // ── My learning ──
            _SectionHeader(
              title: 'My Learning',
              actionLabel: 'Browse',
              onAction: () => context.go('/courses'),
            ),
            const SizedBox(height: DS.s12),
            SizedBox(
              height: 140,
              child: enrollmentsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: DS.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (enr) {
                  if (enr.isEmpty) {
                    return _InlineEmpty(
                      icon: Icons.menu_book_outlined,
                      message: 'No courses yet',
                      action: 'Enroll now',
                      onAction: () => context.go('/courses'),
                    );
                  }
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: enr.length,
                    separatorBuilder: (_, __) => const SizedBox(width: DS.s12),
                    itemBuilder: (_, i) => _EnrolledTile(
                      enrollment: enr[i],
                      index: i,
                      onTap: () =>
                          context.push('/course-player/${enr[i].courseId}'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: DS.s24),

            // ── Tests ──
            _SectionHeader(
              title: 'Tests',
              actionLabel: 'All tests',
              onAction: () => context.push('/tests'),
            ),
            const SizedBox(height: DS.s12),
            testsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: DS.primary,
                  strokeWidth: 2.5,
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (tests) => Column(
                children: tests
                    .take(2)
                    .toList()
                    .asMap()
                    .entries
                    .map(
                      (e) => _TestRow(
                        index: e.key,
                        title: e.value.title,
                        subject: e.value.subject,
                        durationMin: e.value.durationMinutes,
                        marks: e.value.totalMarks.toInt(),
                        onTap: () => context.push('/test/${e.value.id}'),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: DS.s24),

            // ── Quick access ──
            _SectionHeader(title: 'Quick Access'),
            const SizedBox(height: DS.s12),
            _QuickGrid(context: context),
            const SizedBox(height: DS.s24),

            // ── Recommended courses ──
            _SectionHeader(
              title: 'Recommended for You',
              actionLabel: 'See all',
              onAction: () => context.go('/courses'),
            ),
            const SizedBox(height: DS.s12),
            coursesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: DS.primary,
                  strokeWidth: 2.5,
                ),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (courses) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: courses.take(4).length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.74,
                  crossAxisSpacing: DS.s12,
                  mainAxisSpacing: DS.s12,
                ),
                itemBuilder: (_, i) => _RecommendedTile(
                  course: courses[i],
                  onTap: () => context.push('/course/${courses[i].id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CUSTOM APP BAR
// ─────────────────────────────────────────────
class _DashboardAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String name;
  const _DashboardAppBar({required this.name});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(bottom: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s8,
            vertical: DS.s8,
          ),
          child: Row(
            children: [
              // Back
              GestureDetector(
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/home'),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: DS.primaryLight,
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                    border: Border.all(
                      color: DS.primary.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: DS.primary,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: DS.s12),

              // Title
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8C38), DS.primary],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: DS.s10),
                  const Text(
                    'Student Dashboard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: DS.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Notifications
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () => ctx.push('/notifications'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: DS.surfaceVariant,
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                          border: Border.all(color: DS.border, width: 1),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          size: 18,
                          color: DS.textSecondary,
                        ),
                      ),
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: DS.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: DS.surface, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: DS.s8),

              // Menu
              Builder(
                builder: (ctx) => GestureDetector(
                  onTap: () => Scaffold.of(ctx).openEndDrawer(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: DS.surfaceVariant,
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                      border: Border.all(color: DS.border, width: 1),
                    ),
                    child: const Icon(
                      Icons.menu_rounded,
                      size: 18,
                      color: DS.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GREETING HERO CARD
// ─────────────────────────────────────────────
class _GreetingCard extends ConsumerWidget {
  final String name, goal, region;
  const _GreetingCard({
    required this.name,
    required this.goal,
    required this.region,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning ☀️';
    if (h < 17) return 'Good afternoon 👋';
    return 'Good evening 🌙';
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'L';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarUrl = ref.watch(userProfileProvider).valueOrNull?.avatarUrl;
    return Container(
      padding: const EdgeInsets.all(DS.s20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8C38), DS.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(DS.radiusLg),
        boxShadow: [
          BoxShadow(
            color: DS.primary.withOpacity(0.32),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + greeting
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.40),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => Center(
                            child: Text(
                              _initials(name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, _) => Center(
                            child: Text(
                              _initials(name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _initials(name),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: DS.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.80),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: DS.s2),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Streak badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s10,
                  vertical: DS.s8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.30),
                    width: 1,
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(height: DS.s2),
                    Text(
                      '7d',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: DS.s16),

          // Pills row
          Row(
            children: [
              _Pill(icon: Icons.flag_outlined, label: goal),
              const SizedBox(width: DS.s8),
              _Pill(
                icon: Icons.public_rounded,
                label: region == 'AE' ? '🇦🇪 Dubai' : '🇮🇳 India',
              ),
              const Spacer(),
              _Pill(icon: Icons.calendar_today_rounded, label: _dateLabel()),
            ],
          ),
        ],
      ),
    );
  }

  String _dateLabel() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${now.day} ${months[now.month - 1]}';
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s10, vertical: DS.s6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 12),
        const SizedBox(width: DS.s4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// STATS GRID
// ─────────────────────────────────────────────
class _StatsGrid extends ConsumerWidget {
  final AsyncValue<List<Enrollment>> enrollmentsAsync;
  const _StatsGrid({required this.enrollmentsAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollCount = enrollmentsAsync.value?.length ?? 0;
    final statsAsync = ref.watch(_dashboardStatsProvider);
    final testsAttempted = statsAsync.value?.testsAttempted ?? 0;
    final testsLabel = statsAsync.isLoading ? '…' : '$testsAttempted';
    final stats = [
      _StatData(
        Icons.timer_outlined,
        'Hours Studied',
        '—',
        const Color(0xFF6366F1),
      ),
      _StatData(Icons.quiz_outlined, 'Tests Attempted', testsLabel, DS.primary),
      _StatData(Icons.leaderboard_outlined, 'Current Rank', '—', DS.success),
      _StatData(
        Icons.menu_book_outlined,
        'Enrolled',
        '$enrollCount',
        DS.warning,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.65,
        crossAxisSpacing: DS.s12,
        mainAxisSpacing: DS.s12,
      ),
      itemBuilder: (_, i) => _StatCard(data: stats[i]),
    );
  }
}

class _StatData {
  final IconData icon;
  final String label, value;
  final Color color;
  const _StatData(this.icon, this.label, this.value, this.color);
}

class _StatCard extends StatelessWidget {
  final _StatData data;
  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s14),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(width: DS.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.value,
                  style: const TextStyle(
                    color: DS.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: DS.s2),
                Text(
                  data.label,
                  style: const TextStyle(color: DS.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: DS.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: DS.s8),
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
                  color: DS.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// CONTINUE LEARNING CARD
// ─────────────────────────────────────────────
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
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(DS.s14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  child: thumb.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          width: 86,
                          height: 66,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 86,
                            height: 66,
                            color: DS.primaryLight,
                          ),
                        )
                      : Container(
                          width: 86,
                          height: 66,
                          decoration: BoxDecoration(
                            color: DS.primaryLight,
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: DS.primary,
                            size: 28,
                          ),
                        ),
                ),
                const SizedBox(width: DS.s12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DS.s6,
                          vertical: DS.s2,
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
                              size: 11,
                              color: DS.primary,
                            ),
                            SizedBox(width: DS.s2),
                            Text(
                              'Continue Learning',
                              style: TextStyle(
                                color: DS.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: DS.s6),
                      Text(
                        enrollment.lastLessonTitle ??
                            enrollment.courseTitle ??
                            'Course',
                        style: const TextStyle(
                          color: DS.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: DS.s4),
                      Text(
                        '$pct% complete',
                        style: const TextStyle(
                          color: DS.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Progress + button
          Padding(
            padding: const EdgeInsets.fromLTRB(DS.s14, 0, DS.s14, DS.s14),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: enrollment.progressFraction,
                    minHeight: 6,
                    backgroundColor: DS.border,
                    color: DS.primary,
                  ),
                ),
                const SizedBox(height: DS.s12),
                SizedBox(
                  width: double.infinity,
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
                          color: DS.primary.withOpacity(0.28),
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
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LIVE CLASS TILE
// ─────────────────────────────────────────────
class _LiveTile extends StatelessWidget {
  final LiveClass live;
  final VoidCallback onTap;
  const _LiveTile({required this.live, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isLive = live.isLive;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(DS.s14),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(
            color: isLive ? DS.error.withOpacity(0.25) : DS.border,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isLive ? DS.error : Colors.black).withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s4,
                  ),
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
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s6,
                    vertical: DS.s2,
                  ),
                  decoration: BoxDecoration(
                    color: DS.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    live.subject,
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 10,
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
                color: DS.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: -0.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: DS.s6),

            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: DS.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 10,
                    color: DS.primary,
                  ),
                ),
                const SizedBox(width: DS.s4),
                Expanded(
                  child: Text(
                    live.educatorName,
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 11.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const Spacer(),
            const Divider(color: DS.border, height: DS.s16, thickness: 1),

            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 12,
                  color: isLive ? DS.error : DS.textSecondary,
                ),
                const SizedBox(width: DS.s4),
                Expanded(
                  child: Text(
                    _fmt(live.startsAt),
                    style: TextStyle(
                      color: isLive ? DS.error : DS.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s6,
                    vertical: DS.s2,
                  ),
                  decoration: BoxDecoration(
                    color: isLive
                        ? DS.error.withOpacity(0.08)
                        : DS.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isLive ? 'Join' : 'Remind',
                    style: TextStyle(
                      color: isLive ? DS.error : DS.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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
          : 'In ${diff.inMinutes}m';
    }
    if (diff.inHours.abs() < 24) return 'In ${diff.inHours}h';
    return '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────
// ENROLLED TILE
// ─────────────────────────────────────────────
class _EnrolledTile extends StatelessWidget {
  final Enrollment enrollment;
  final int index;
  final VoidCallback onTap;

  const _EnrolledTile({
    required this.enrollment,
    required this.index,
    required this.onTap,
  });

  static const _accentColors = [
    DS.primary,
    DS.indigo,
    DS.success,
    DS.warning,
    DS.purple,
    DS.cyan,
  ];

  Color get _accent => _accentColors[index % _accentColors.length];

  @override
  Widget build(BuildContext context) {
    final thumb = enrollment.courseThumbnailUrl ?? '';
    final pct = enrollment.progressPercent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(DS.s12),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail + subject
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  child: thumb.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumb,
                          width: 52,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 52,
                            height: 40,
                            color: DS.primaryLight,
                          ),
                        )
                      : Container(
                          width: 52,
                          height: 40,
                          decoration: BoxDecoration(
                            color: DS.primaryLight,
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: DS.primary,
                            size: 20,
                          ),
                        ),
                ),
                const SizedBox(width: DS.s8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s6,
                      vertical: DS.s2,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      enrollment.courseSubject ?? 'Course',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DS.s8),

            // Title
            Text(
              enrollment.courseTitle ?? 'Course',
              style: const TextStyle(
                color: DS.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const Spacer(),

            // Progress
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: enrollment.progressFraction,
                minHeight: 5,
                backgroundColor: DS.border,
                color: _accent,
              ),
            ),
            const SizedBox(height: DS.s4),
            Text(
              '$pct% complete',
              style: TextStyle(
                color: _accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TEST ROW
// ─────────────────────────────────────────────
class _TestRow extends StatelessWidget {
  final int index;
  final String title, subject;
  final int durationMin, marks;
  final VoidCallback onTap;

  const _TestRow({
    required this.index,
    required this.title,
    required this.subject,
    required this.durationMin,
    required this.marks,
    required this.onTap,
  });

  static const _colors = [DS.primary, DS.indigo];
  Color get _color => _colors[index % _colors.length];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s10),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.all(DS.s14),
          decoration: BoxDecoration(
            color: DS.surface,
            borderRadius: BorderRadius.circular(DS.radiusMd),
            border: Border.all(color: DS.border, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon tile
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
                child: Icon(Icons.assignment_outlined, color: _color, size: 22),
              ),
              const SizedBox(width: DS.s12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: DS.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: DS.s4),
                    Row(
                      children: [
                        _TestMeta(label: subject),
                        const SizedBox(width: DS.s6),
                        _TestMeta(label: '${durationMin}m'),
                        const SizedBox(width: DS.s6),
                        _TestMeta(label: '$marks marks'),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: _color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestMeta extends StatelessWidget {
  final String label;
  const _TestMeta({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s6, vertical: DS.s2),
    decoration: BoxDecoration(
      color: DS.surfaceVariant,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: DS.border),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: DS.textSecondary,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// QUICK ACCESS GRID
// ─────────────────────────────────────────────
class _QuickGrid extends StatelessWidget {
  final BuildContext context;
  const _QuickGrid({required this.context});

  @override
  Widget build(BuildContext ctx) {
    final items = [
      _QuickData(Icons.psychology_outlined, 'Doubts', '/doubts', DS.indigo),
      _QuickData(Icons.quiz_outlined, 'Tests', '/tests', DS.primary),
      _QuickData(
        Icons.chat_bubble_outline_rounded,
        'Mentor',
        '/mentor-chat',
        DS.teal,
      ),
      _QuickData(Icons.flash_on_rounded, 'Compete', '/compete', DS.error),
      _QuickData(Icons.insights_rounded, 'Analytics', '/analytics', DS.success),
      _QuickData(
        Icons.emoji_events_outlined,
        'Leaderboard',
        '/leaderboard',
        DS.warning,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.95,
        crossAxisSpacing: DS.s12,
        mainAxisSpacing: DS.s12,
      ),
      itemBuilder: (_, i) =>
          _QuickTile(data: items[i], onTap: () => context.push(items[i].route)),
    );
  }
}

class _QuickData {
  final IconData icon;
  final String label, route;
  final Color color;
  const _QuickData(this.icon, this.label, this.route, this.color);
}

class _QuickTile extends StatelessWidget {
  final _QuickData data;
  final VoidCallback onTap;
  const _QuickTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: data.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(DS.radiusMd),
              ),
              child: Icon(data.icon, color: data.color, size: 22),
            ),
            const SizedBox(height: DS.s8),
            Text(
              data.label,
              style: const TextStyle(
                color: DS.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RECOMMENDED COURSE TILE
// ─────────────────────────────────────────────
class _RecommendedTile extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  const _RecommendedTile({required this.course, required this.onTap});

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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DS.radiusLg),
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: course.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: course.thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: DS.primaryLight),
                          )
                        : Container(
                            color: DS.primaryLight,
                            child: const Icon(
                              Icons.menu_book_rounded,
                              color: DS.primary,
                            ),
                          ),
                  ),
                  if (course.isFree)
                    Positioned(
                      top: DS.s6,
                      left: DS.s6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DS.s6,
                          vertical: DS.s2,
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
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DS.s10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(
                        color: DS.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: DS.s4),
                    Text(
                      course.educator,
                      style: const TextStyle(
                        color: DS.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: DS.warning,
                        ),
                        const SizedBox(width: DS.s2),
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

// ─────────────────────────────────────────────
// INLINE EMPTY STATE
// ─────────────────────────────────────────────
class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  const _InlineEmpty({
    required this.icon,
    required this.message,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: DS.surfaceVariant,
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: Icon(icon, color: DS.textHint, size: 22),
          ),
          const SizedBox(height: DS.s8),
          Text(
            message,
            style: const TextStyle(color: DS.textSecondary, fontSize: 13),
          ),
          if (action != null) ...[
            const SizedBox(height: DS.s6),
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: const TextStyle(
                  color: DS.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INLINE ERROR
// ─────────────────────────────────────────────
class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      message,
      style: const TextStyle(color: DS.textSecondary, fontSize: 13),
    ),
  );
}

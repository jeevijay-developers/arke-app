import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../enrollments/data/enrollments_providers.dart';
import '../enrollments/data/models/enrollment.dart';

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
  static const double s48 = 48;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// MY LEARNING SCREEN
// ─────────────────────────────────────────────
class MyLearningScreen extends ConsumerWidget {
  const MyLearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollmentsAsync = ref.watch(enrollmentsProvider);

    return Scaffold(
      backgroundColor: DS.background,
      body: enrollmentsAsync.when(
        loading: () => const Scaffold(
          backgroundColor: DS.background,
          body: Center(
            child: CircularProgressIndicator(
              color: DS.primary,
              strokeWidth: 2.5,
            ),
          ),
        ),
        error: (e, _) => Scaffold(
          backgroundColor: DS.background,
          body: _ErrorState(message: 'Error: $e'),
        ),
        data: (enrollments) => enrollments.isEmpty
            ? _EmptyScreen(onBrowse: () => context.go('/courses'))
            : _LoadedScreen(
                enrollments: enrollments,
                ref: ref,
                onBrowse: () => context.go('/courses'),
                onBack: () => context.pop(),
                onCardTap: (courseId) =>
                    context.push('/my-courses/$courseId'),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOADED SCREEN
// ─────────────────────────────────────────────
class _LoadedScreen extends StatelessWidget {
  final List<Enrollment> enrollments;
  final WidgetRef ref;
  final VoidCallback onBrowse;
  final VoidCallback onBack;
  final void Function(String courseId) onCardTap;

  const _LoadedScreen({
    required this.enrollments,
    required this.ref,
    required this.onBrowse,
    required this.onBack,
    required this.onCardTap,
  });



  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Orange hero header ──
        SliverPersistentHeader(
          pinned: true,
          delegate: _MyLearningHeaderDelegate(
            enrollmentCount: enrollments.length,
            onBack: onBack,
            onBrowse: onBrowse,
          ),
        ),

        // ── Section header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(DS.s16, DS.s24, DS.s16, DS.s12),
            child: Row(
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
                const Text(
                  'Your Courses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DS.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s4,
                  ),
                  decoration: BoxDecoration(
                    color: DS.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: DS.border),
                  ),
                  child: Text(
                    '${enrollments.length} enrolled',
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Enrollment cards ──
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(DS.s16, 0, DS.s16, DS.s32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _EnrollmentCard(
                enrollment: enrollments[i],
                index: i,
                onTap: () => onCardTap(enrollments[i].courseId),
              ),
              childCount: enrollments.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SLIVER HEADER DELEGATE
// ─────────────────────────────────────────────
class _MyLearningHeaderDelegate extends SliverPersistentHeaderDelegate {
  final int enrollmentCount;
  final VoidCallback onBack;
  final VoidCallback onBrowse;

  const _MyLearningHeaderDelegate({
    required this.enrollmentCount,
    required this.onBack,
    required this.onBrowse,
  });

  @override
  double get minExtent => 70;
  @override
  double get maxExtent => 200;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool _) {
    final progress = (shrinkOffset / maxExtent).clamp(0.0, 1.0);
    final collapsed = progress > 0.45;

    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C38), DS.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(DS.radiusXl),
              bottomRight: Radius.circular(DS.radiusXl),
            ),
            boxShadow: [
              BoxShadow(
                color: DS.primary.withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        ),

        // Decorative circles
        Positioned(
          top: -40,
          right: -30,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          left: -20,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),

        // Content
        SafeArea(
          bottom: false,
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: collapsed
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,

            // ── Expanded ──
            firstChild: Padding(
              padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Back
                      GestureDetector(
                        onTap: onBack,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Browse more pill
                      GestureDetector(
                        onTap: onBrowse,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DS.s10,
                            vertical: DS.s4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.30),
                              width: 1,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                              SizedBox(width: DS.s4),
                              Text(
                                'Browse More',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DS.s4),
                  const Text(
                    'My Learning 📚',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$enrollmentCount course${enrollmentCount == 1 ? '' : 's'} enrolled · Keep going!',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withOpacity(0.80),
                    ),
                  ),
                ],
              ),
            ),

            // ── Collapsed ──
            secondChild: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DS.s16,
                vertical: DS.s16,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s12),
                  const Text(
                    'My Learning',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onBrowse,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DS.s10,
                        vertical: DS.s6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '+ Browse',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _MyLearningHeaderDelegate old) =>
      enrollmentCount != old.enrollmentCount;
}

// ─────────────────────────────────────────────
// ENROLLMENT CARD
// ─────────────────────────────────────────────
class _EnrollmentCard extends StatelessWidget {
  final Enrollment enrollment;
  final int index;
  final VoidCallback onTap;

  const _EnrollmentCard({
    required this.enrollment,
    required this.index,
    required this.onTap,
  });

  // Accent colors per card — cycles through a palette
  static const _accentColors = [
    DS.primary,
    DS.indigo,
    DS.success,
    DS.warning,
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
  ];

  Color get _accent => _accentColors[index % _accentColors.length];

  @override
  Widget build(BuildContext context) {
    final thumb = enrollment.courseThumbnailUrl ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s12),
      child: GestureDetector(
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
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top: thumbnail + info ──
              Padding(
                padding: const EdgeInsets.all(DS.s14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Thumbnail
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                          child: thumb.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: thumb,
                                  width: 80,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    width: 80,
                                    height: 64,
                                    color: DS.primaryLight,
                                  ),
                                )
                              : Container(
                                  width: 80,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: DS.primaryLight,
                                    borderRadius: BorderRadius.circular(
                                      DS.radiusSm,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.menu_book_rounded,
                                    color: DS.primary,
                                    size: 28,
                                  ),
                                ),
                        ),
                      ],
                    ),

                    const SizedBox(width: DS.s12),

                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Subject chip
                          if (enrollment.courseSubject != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DS.s6,
                                vertical: DS.s2,
                              ),
                              decoration: BoxDecoration(
                                color: _accent.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                enrollment.courseSubject!,
                                style: TextStyle(
                                  color: _accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),

                          const SizedBox(height: DS.s6),

                          // Title
                          Text(
                            enrollment.courseTitle ?? 'Course',
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

                          // Educator
                          if (enrollment.courseEducatorName != null) ...[
                            const SizedBox(height: DS.s4),
                            Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _accent.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      enrollment.courseEducatorName![0]
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: _accent,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: DS.s4),
                                Expanded(
                                  child: Text(
                                    enrollment.courseEducatorName!,
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
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: DS.s6),

                    // Play icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: DS.primaryLight,
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: DS.primary,
                        size: 18,
                      ),
                    ),
                  ],
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
// EMPTY SCREEN
// ─────────────────────────────────────────────
class _EmptyScreen extends StatelessWidget {
  final VoidCallback onBrowse;
  const _EmptyScreen({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.primary,
      body: Stack(
        children: [
          // ── Decorative background ──
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          Column(
            children: [
              // ── Orange hero ──
              Expanded(
                flex: 35,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DS.s20,
                      DS.s12,
                      DS.s16,
                      DS.s20,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(
                                    DS.radiusSm,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.28),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: DS.s16),
                        const Text(
                          'My Learning 📚',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),

              // ── White card ──
              Expanded(
                flex: 65,
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: DS.background,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(DS.radiusXl),
                      topRight: Radius.circular(DS.radiusXl),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      DS.s24,
                      DS.s32,
                      DS.s24,
                      DS.s32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card header
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 28,
                              decoration: BoxDecoration(
                                color: DS.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: DS.s12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'No courses yet',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: DS.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Start your learning journey today',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: DS.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: DS.s28),

                        // Illustration
                        Container(
                          width: double.infinity,
                          height: 160,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                DS.primaryLight,
                                DS.primary.withOpacity(0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(DS.radiusLg),
                            border: Border.all(
                              color: DS.primary.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background circles
                              Positioned(
                                top: 20,
                                left: 30,
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: DS.primary.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 15,
                                right: 40,
                                child: Container(
                                  width: 35,
                                  height: 35,
                                  decoration: BoxDecoration(
                                    color: DS.primary.withOpacity(0.06),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              // Icon
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: DS.surface,
                                  borderRadius: BorderRadius.circular(
                                    DS.radiusMd,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: DS.primary.withOpacity(0.15),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.menu_book_outlined,
                                  color: DS.primary,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: DS.s24),

                        const Text(
                          'Explore our library of JEE, NEET & Foundation courses tailored for your exam success.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: DS.textSecondary,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: DS.s28),

                        // Feature chips
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _FeatureChip(
                              icon: Icons.play_circle_outline_rounded,
                              label: 'Video Lectures',
                            ),
                            const SizedBox(width: DS.s10),
                            _FeatureChip(
                              icon: Icons.quiz_outlined,
                              label: 'Mock Tests',
                            ),
                            const SizedBox(width: DS.s10),
                            _FeatureChip(
                              icon: Icons.picture_as_pdf_outlined,
                              label: 'PDF Notes',
                            ),
                          ],
                        ),

                        const SizedBox(height: DS.s28),

                        // Browse button
                        SizedBox(
                          height: 54,
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
                                  color: DS.primary.withOpacity(0.32),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: onBrowse,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    DS.radiusMd,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.explore_rounded, size: 20),
                              label: const Text(
                                'Explore Courses',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FEATURE CHIP
// ─────────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s10, vertical: DS.s6),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: DS.primary),
          const SizedBox(width: DS.s4),
          Text(
            label,
            style: const TextStyle(
              color: DS.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: DS.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: DS.error,
                size: 32,
              ),
            ),
            const SizedBox(height: DS.s16),
            Text(
              message,
              style: const TextStyle(color: DS.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

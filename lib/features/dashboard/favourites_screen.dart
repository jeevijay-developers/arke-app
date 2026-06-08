import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../courses/data/favourites_provider.dart';
import '../courses/data/models/course.dart';

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
// FAVOURITES SCREEN
// ─────────────────────────────────────────────
class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(favouriteCoursesProvider);
    final favouriteIds = ref.watch(favouritesProvider);
    final count = favouriteIds.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: Column(
          children: [
            // ── Orange gradient header ──
            _FavouritesHeader(count: count, onBack: () => context.pop()),

            // ── Content ──
            Expanded(
              child: coursesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: DS.primary,
                    strokeWidth: 2.5,
                  ),
                ),
                error: (e, _) => _ErrorState(
                  onRetry: () => ref.invalidate(favouriteCoursesProvider),
                ),
                data: (courses) {
                  if (courses.isEmpty) return const _EmptyState();

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      DS.s16,
                      DS.s20,
                      DS.s16,
                      DS.s32,
                    ),
                    itemCount: courses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: DS.s12),
                    itemBuilder: (_, i) => _FavouriteCourseCard(
                      course: courses[i],
                      index: i,
                      onRemove: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(favouritesProvider.notifier)
                            .toggle(courses[i].id);
                      },
                      onTap: () => context.push('/course/${courses[i].id}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FAVOURITES HEADER
// ─────────────────────────────────────────────
class _FavouritesHeader extends StatelessWidget {
  final int count;
  final VoidCallback onBack;

  const _FavouritesHeader({required this.count, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient bg
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF8C38), DS.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(DS.radiusXl),
              bottomRight: Radius.circular(DS.radiusXl),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x47F97315),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(DS.s8, DS.s8, DS.s16, DS.s24),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 36,
                      height: 36,
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

                  // Heart icon + title
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.28),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: DS.s12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favourites',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Your saved courses',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Count badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s12,
                      vertical: DS.s6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.28),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: DS.s4),
                        Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Decorative circles
        Positioned(
          top: -50,
          right: -30,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          top: 15,
          right: 20,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// FAVOURITE COURSE CARD
// ─────────────────────────────────────────────
class _FavouriteCourseCard extends StatelessWidget {
  final Course course;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  static const _accentColors = [
    DS.primary,
    Color(0xFF6366F1),
    DS.success,
    DS.warning,
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
  ];

  const _FavouriteCourseCard({
    required this.course,
    required this.index,
    required this.onRemove,
    required this.onTap,
  });

  Color get _accent => _accentColors[index % _accentColors.length];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
          children: [
            // Accent top bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(DS.radiusMd),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(DS.s12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                    child: SizedBox(
                      width: 90,
                      height: 72,
                      child: (course.thumbnailUrl ?? '').isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: course.thumbnailUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: DS.primaryLight),
                              errorWidget: (_, __, ___) => Container(
                                color: DS.primaryLight,
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: DS.primary,
                                  size: 28,
                                ),
                              ),
                            )
                          : Container(
                              color: DS.primaryLight,
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: DS.primary,
                                size: 28,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(width: DS.s12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subject chip
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
                            course.target.toUpperCase(),
                            style: TextStyle(
                              color: _accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: DS.s6),

                        // Title
                        Text(
                          course.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: DS.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            letterSpacing: -0.1,
                          ),
                        ),
                        const SizedBox(height: DS.s6),

                        // Educator + price
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 12,
                              color: DS.textHint,
                            ),
                            const SizedBox(width: DS.s4),
                            Expanded(
                              child: Text(
                                course.teacherName ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: DS.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: DS.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DS.s8,
                                vertical: DS.s2,
                              ),
                              decoration: BoxDecoration(
                                color: course.isCourseFree
                                    ? DS.successSurface
                                    : DS.primaryLight,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                course.isCourseFree
                                    ? 'Free'
                                    : '₹${course.displayPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: course.isCourseFree
                                      ? DS.success
                                      : DS.primary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: DS.s8),

                  // Remove heart button
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: DS.errorSurface,
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                        border: Border.all(
                          color: DS.error.withOpacity(0.20),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: DS.error,
                        size: 16,
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

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C38), DS.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(DS.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: DS.primary.withOpacity(0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.favorite_border_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: DS.s20),
            const Text(
              'No Favourites Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: DS.s8),
            const Text(
              'Tap the heart icon on any course to save it here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DS.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: DS.s28),
            SizedBox(
              height: 50,
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
                      color: DS.primary.withOpacity(0.30),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/courses'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: DS.s24),
                  ),
                  icon: const Icon(Icons.explore_outlined, size: 18),
                  label: const Text(
                    'Browse Courses',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
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
// ERROR STATE
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

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
              decoration: BoxDecoration(
                color: DS.errorSurface,
                borderRadius: BorderRadius.circular(DS.radiusLg),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: DS.error,
                size: 30,
              ),
            ),
            const SizedBox(height: DS.s16),
            const Text(
              'Failed to Load',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s8),
            const Text(
              'Could not load your saved courses.\nPlease try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DS.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DS.s24),
            SizedBox(
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8C38), DS.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                ),
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Retry',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

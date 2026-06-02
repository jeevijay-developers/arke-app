import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'pdf_viewer_screen.dart';
import 'data/courses_providers.dart';
import 'data/favourites_provider.dart';
import 'data/models/course.dart';
import 'data/models/lesson.dart';
import '../enrollments/data/enrollments_providers.dart';
import '../tests/data/tests_providers.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/razorpay_service.dart';

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

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// COURSE DETAIL SCREEN
// ─────────────────────────────────────────────
class CourseDetailScreen extends ConsumerWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));
    return courseAsync.when(
      loading: () => const Scaffold(
        backgroundColor: DS.background,
        body: Center(
          child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: DS.background,
        body: Center(child: _ErrorState(message: 'Failed to load course: $e')),
      ),
      data: (course) => _CourseDetailBody(course: course, courseId: courseId),
    );
  }
}

// ─────────────────────────────────────────────
// MAIN BODY
// ─────────────────────────────────────────────
class _CourseDetailBody extends ConsumerStatefulWidget {
  final Course course;
  final String courseId;
  const _CourseDetailBody({required this.course, required this.courseId});

  @override
  ConsumerState<_CourseDetailBody> createState() => _CourseDetailBodyState();
}

class _CourseDetailBodyState extends ConsumerState<_CourseDetailBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  static const _tabs = ['About', 'Lectures', 'Tests', 'PDF Notes', 'Time'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final lessonsAsync = ref.watch(lessonsProvider(widget.courseId));
    final reviewsAsync = ref.watch(courseReviewsProvider(widget.courseId));
    final pdfsAsync = ref.watch(coursePdfsProvider(widget.courseId));
    final enrolledCount = ref
        .watch(courseEnrolledCountProvider(widget.courseId))
        .valueOrNull;

    final lessonCount =
        lessonsAsync.valueOrNull?.length ?? course.totalLessons ?? 0;
    final pdfCount = pdfsAsync.valueOrNull?.length ?? 0;
    final reviewCount = reviewsAsync.valueOrNull?.length ?? 0;
    final avgRating =
        reviewsAsync.valueOrNull == null || reviewsAsync.valueOrNull!.isEmpty
        ? course.rating
        : reviewsAsync.valueOrNull!.fold<double>(0, (s, r) => s + r.rating) /
              reviewsAsync.valueOrNull!.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: NestedScrollView(
          headerSliverBuilder: (ctx, _) => [
            _CourseHeader(
              course: course,
              avgRating: avgRating,
              reviewCount: reviewCount,
              lessonCount: lessonCount,
              pdfCount: pdfCount,
              enrolledCount: enrolledCount,
              tabCtrl: _tabCtrl,
              tabs: _tabs,
            ),
          ],
          body: TabBarView(
            controller: _tabCtrl,
            children: [
              _AboutTab(course: course),
              _LecturesTab(
                lessonsAsync: lessonsAsync,
                courseId: widget.courseId,
              ),
              _TestsTab(courseId: widget.courseId),
              _PdfsTab(pdfsAsync: pdfsAsync, courseId: widget.courseId),
              _TimeTab(course: course),
            ],
          ),
        ),
        bottomNavigationBar: _EnrollBar(
          course: course,
          courseId: widget.courseId,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COURSE SLIVER HEADER
// ─────────────────────────────────────────────
class _CourseHeader extends ConsumerWidget {
  final Course course;
  final double avgRating;
  final int reviewCount;
  final int lessonCount;
  final int pdfCount;
  final int? enrolledCount;
  final TabController tabCtrl;
  final List<String> tabs;

  const _CourseHeader({
    required this.course,
    required this.avgRating,
    required this.reviewCount,
    required this.lessonCount,
    required this.pdfCount,
    required this.enrolledCount,
    required this.tabCtrl,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectBadge =
        '${course.subject.toUpperCase()} · ${(course.level ?? 'JEE').toUpperCase()}';

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Full-width thumbnail with orange overlay + back button ──
          Stack(
            children: [
              // Thumbnail
              AspectRatio(
                aspectRatio: 16 / 9,
                child: course.thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: course.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: DS.primaryLight),
                      )
                    : Container(
                        color: DS.primaryLight,
                        child: const Center(
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: DS.primary,
                            size: 64,
                          ),
                        ),
                      ),
              ),

              // Gradient overlay
              AspectRatio(
                aspectRatio: 16 / 9,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.45),
                        Colors.black.withOpacity(0.10),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Back button + title
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s8,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.black.withOpacity(0.30),
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                          onTap: () => context.pop(),
                          child: const Padding(
                            padding: EdgeInsets.all(DS.s8),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: DS.s10),
                      const Expanded(
                        child: Text(
                          'Course Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Favourite heart button
                      _FavouriteButton(courseId: course.id, ref: ref),
                    ],
                  ),
                ),
              ),

              // Free / Price badge on thumbnail
              Positioned(
                bottom: DS.s12,
                left: DS.s16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s10,
                    vertical: DS.s6,
                  ),
                  decoration: BoxDecoration(
                    color: course.isFree ? DS.success : DS.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    course.isFree
                        ? '🎓 FREE'
                        : '₹${course.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Course info card ──
          Container(
            color: DS.surface,
            padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s4,
                  ),
                  decoration: BoxDecoration(
                    color: DS.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    subjectBadge,
                    style: const TextStyle(
                      color: DS.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: DS.s10),

                // Title
                Text(
                  course.title,
                  style: const TextStyle(
                    color: DS.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: DS.s8),

                // Description
                if (course.description != null)
                  Text(
                    course.description!,
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                const SizedBox(height: DS.s12),

                // Rating + enrolled row
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: DS.warning, size: 16),
                    const SizedBox(width: DS.s4),
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: DS.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      '  ($reviewCount reviews)',
                      style: const TextStyle(
                        color: DS.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    if (enrolledCount != null) ...[
                      const SizedBox(width: DS.s12),
                      const Icon(
                        Icons.people_outline_rounded,
                        size: 14,
                        color: DS.textSecondary,
                      ),
                      const SizedBox(width: DS.s4),
                      Text(
                        '${_fmtNum(enrolledCount!)} enrolled',
                        style: const TextStyle(
                          color: DS.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: DS.s12),

                // Educator row
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8C38), DS.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          course.educator.isNotEmpty
                              ? course.educator[0].toUpperCase()
                              : 'T',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: DS.s8),
                    Text(
                      'By ',
                      style: const TextStyle(
                        color: DS.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      course.educator,
                      style: const TextStyle(
                        color: DS.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      ' · ${course.subject} Dept.',
                      style: const TextStyle(
                        color: DS.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: DS.s8),

          // ── Stats bar ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: DS.s16),
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
                _StatBox(
                  value: '$lessonCount',
                  label: 'Lectures',
                  icon: Icons.play_circle_outline_rounded,
                  color: DS.indigo,
                ),
                _VDivider(),
                _StatBox(
                  value: '${course.totalLessons ?? '—'}',
                  label: 'Tests',
                  icon: Icons.assignment_outlined,
                  color: DS.primary,
                ),
                _VDivider(),
                _StatBox(
                  value: '$pdfCount',
                  label: 'PDFs',
                  icon: Icons.picture_as_pdf_outlined,
                  color: DS.error,
                ),
                _VDivider(),
                _StatBox(
                  value: '${course.durationHours ?? 0}h',
                  label: 'Duration',
                  icon: Icons.schedule_rounded,
                  color: DS.success,
                ),
                _VDivider(),
                _StatBox(
                  value: '${avgRating.toStringAsFixed(1)}★',
                  label: 'Rating',
                  icon: Icons.star_rounded,
                  color: DS.warning,
                ),
              ],
            ),
          ),

          const SizedBox(height: DS.s12),

          // ── Tab bar ──
          Container(
            color: DS.surface,
            child: TabBar(
              controller: tabCtrl,
              labelColor: DS.primary,
              unselectedLabelColor: DS.textSecondary,
              indicatorColor: DS.primary,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: DS.s8),
              tabs: tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtNum(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}K' : '$n';
}

// ─────────────────────────────────────────────
// STAT BOX
// ─────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatBox({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: DS.s14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: DS.s4),
          Text(
            value,
            style: const TextStyle(
              color: DS.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: DS.s2),
          Text(
            label,
            style: const TextStyle(color: DS.textSecondary, fontSize: 10.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _VDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 48, color: DS.border);
}

// ─────────────────────────────────────────────
// FAVOURITE BUTTON
// ─────────────────────────────────────────────
class _FavouriteButton extends StatelessWidget {
  final String courseId;
  final WidgetRef ref;
  const _FavouriteButton({required this.courseId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isFav = ref.watch(favouritesProvider).contains(courseId);
    return Material(
      color: Colors.black.withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(DS.radiusSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(DS.radiusSm),
        onTap: () => ref.read(favouritesProvider.notifier).toggle(courseId),
        child: Padding(
          padding: const EdgeInsets.all(DS.s8),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFav ? const Color(0xFFFF4D6D) : Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ABOUT TAB
// ─────────────────────────────────────────────
class _AboutTab extends StatelessWidget {
  final Course course;
  const _AboutTab({required this.course});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(DS.s16),
      children: [
        if (course.description != null) ...[
          _TabSectionLabel(label: 'About This Course'),
          const SizedBox(height: DS.s10),
          Container(
            padding: const EdgeInsets.all(DS.s16),
            decoration: BoxDecoration(
              color: DS.surface,
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(color: DS.border, width: 1.2),
            ),
            child: Text(
              course.description!,
              style: const TextStyle(
                color: DS.textPrimary,
                fontSize: 14,
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: DS.s20),
        ],

        if (course.whatYoullLearn.isNotEmpty) ...[
          _TabSectionLabel(label: 'What You\'ll Learn'),
          const SizedBox(height: DS.s10),
          Container(
            padding: const EdgeInsets.all(DS.s16),
            decoration: BoxDecoration(
              color: DS.surface,
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(color: DS.border, width: 1.2),
            ),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 4.2,
              crossAxisSpacing: DS.s8,
              mainAxisSpacing: DS.s6,
              children: course.whatYoullLearn
                  .map(
                    (item) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: DS.s2),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: DS.success,
                          ),
                        ),
                        const SizedBox(width: DS.s6),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              color: DS.textPrimary,
                              fontSize: 12.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: DS.s20),
        ],

        if (course.requirements.isNotEmpty) ...[
          _TabSectionLabel(label: 'Requirements'),
          const SizedBox(height: DS.s10),
          Container(
            padding: const EdgeInsets.all(DS.s16),
            decoration: BoxDecoration(
              color: DS.surface,
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(color: DS.border, width: 1.2),
            ),
            child: Column(
              children: course.requirements
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: DS.s8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: DS.s2),
                            child: Icon(
                              Icons.arrow_right_rounded,
                              size: 16,
                              color: DS.primary,
                            ),
                          ),
                          const SizedBox(width: DS.s6),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                color: DS.textPrimary,
                                fontSize: 13.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: DS.s24),
        ],

        _RatingsSection(courseId: course.id),
        const SizedBox(height: DS.s32),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TAB SECTION LABEL
// ─────────────────────────────────────────────
class _TabSectionLabel extends StatelessWidget {
  final String label;
  const _TabSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: DS.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: DS.s8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: DS.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// RATINGS SECTION
// ─────────────────────────────────────────────
class _RatingsSection extends ConsumerStatefulWidget {
  final String courseId;
  const _RatingsSection({required this.courseId});

  @override
  ConsumerState<_RatingsSection> createState() => _RatingsSectionState();
}

class _RatingsSectionState extends ConsumerState<_RatingsSection> {
  int _selectedRating = 0;
  final _reviewCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRating == 0) return;
    setState(() => _submitting = true);
    try {
      final client = SupabaseService.client;
      final userId = client.auth.currentUser!.id;
      final existing = ref.read(myReviewProvider(widget.courseId)).valueOrNull;
      if (existing != null) {
        await client
            .from('course_reviews')
            .update({
              'rating': _selectedRating,
              'review': _reviewCtrl.text.trim().isEmpty
                  ? null
                  : _reviewCtrl.text.trim(),
            })
            .eq('id', existing.id);
      } else {
        await client.from('course_reviews').insert({
          'course_id': widget.courseId,
          'user_id': userId,
          'rating': _selectedRating,
          'review': _reviewCtrl.text.trim().isEmpty
              ? null
              : _reviewCtrl.text.trim(),
        });
      }
      ref.invalidate(courseReviewsProvider(widget.courseId));
      ref.invalidate(myReviewProvider(widget.courseId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review submitted!'),
            backgroundColor: DS.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: DS.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(courseReviewsProvider(widget.courseId));
    final isEnrolledAsync = ref.watch(isEnrolledProvider(widget.courseId));
    final myReviewAsync = ref.watch(myReviewProvider(widget.courseId));
    final isEnrolled = isEnrolledAsync.valueOrNull ?? false;

    myReviewAsync.whenData((existing) {
      if (existing != null && _selectedRating == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted)
            setState(() {
              _selectedRating = existing.rating;
              if (_reviewCtrl.text.isEmpty && existing.review != null) {
                _reviewCtrl.text = existing.review!;
              }
            });
        });
      }
    });

    return reviewsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (reviews) {
        final count = reviews.length;
        final avg = count == 0
            ? 0.0
            : reviews.fold<double>(0, (s, r) => s + r.rating) / count;
        final starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
        for (final r in reviews) {
          starCounts[r.rating.clamp(1, 5)] =
              (starCounts[r.rating.clamp(1, 5)] ?? 0) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              children: [
                _TabSectionLabel(label: 'Ratings & Reviews'),
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
                    '$count review${count == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DS.s12),

            // Rating summary card
            Container(
              padding: const EdgeInsets.all(DS.s16),
              decoration: BoxDecoration(
                color: DS.surface,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(color: DS.border, width: 1.2),
              ),
              child: Row(
                children: [
                  // Big average score
                  SizedBox(
                    width: 88,
                    child: Column(
                      children: [
                        Text(
                          avg.toStringAsFixed(1),
                          style: const TextStyle(
                            color: DS.textPrimary,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(height: DS.s4),
                        _StarRow(rating: avg, size: 13),
                        const SizedBox(height: DS.s4),
                        Text(
                          'Based on $count',
                          style: const TextStyle(
                            color: DS.textSecondary,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DS.s16),

                  // Bar chart
                  Expanded(
                    child: Column(
                      children: [5, 4, 3, 2, 1].map((star) {
                        final c = starCounts[star] ?? 0;
                        final pct = count == 0 ? 0.0 : c / count;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: DS.s2),
                          child: Row(
                            children: [
                              Text(
                                '$star',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: DS.textSecondary,
                                ),
                              ),
                              const SizedBox(width: DS.s2),
                              const Icon(
                                Icons.star_rounded,
                                size: 10,
                                color: DS.warning,
                              ),
                              const SizedBox(width: DS.s6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 7,
                                    backgroundColor: DS.border,
                                    color: DS.warning,
                                  ),
                                ),
                              ),
                              const SizedBox(width: DS.s6),
                              SizedBox(
                                width: 16,
                                child: Text(
                                  '$c',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: DS.textSecondary,
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: DS.s12),

            // Rate form (enrolled) or lock notice
            if (isEnrolled) ...[
              Container(
                padding: const EdgeInsets.all(DS.s16),
                decoration: BoxDecoration(
                  color: DS.surface,
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  border: Border.all(color: DS.border, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      myReviewAsync.valueOrNull != null
                          ? 'Update your review'
                          : 'Rate this course',
                      style: const TextStyle(
                        color: DS.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: DS.s12),
                    Row(
                      children: List.generate(5, (i) {
                        final star = i + 1;
                        final filled = star <= _selectedRating;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedRating = star);
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: DS.s6),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: Icon(
                                Icons.star_rounded,
                                key: ValueKey(filled),
                                size: 36,
                                color: filled ? DS.warning : DS.border,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: DS.s12),
                    TextField(
                      controller: _reviewCtrl,
                      maxLines: 3,
                      style: const TextStyle(
                        fontSize: 14,
                        color: DS.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write your review (optional)',
                        hintStyle: const TextStyle(color: DS.textHint),
                        filled: true,
                        fillColor: DS.background,
                        contentPadding: const EdgeInsets.all(DS.s12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                          borderSide: const BorderSide(color: DS.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                          borderSide: const BorderSide(
                            color: DS.border,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                          borderSide: const BorderSide(
                            color: DS.primary,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: DS.s12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: (_selectedRating == 0 || _submitting)
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFFFF8C38), DS.primary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          color: (_selectedRating == 0 || _submitting)
                              ? DS.border
                              : null,
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                          boxShadow: (_selectedRating == 0 || _submitting)
                              ? []
                              : [
                                  BoxShadow(
                                    color: DS.primary.withOpacity(0.28),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: ElevatedButton(
                          onPressed: (_selectedRating == 0 || _submitting)
                              ? null
                              : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(DS.radiusMd),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  myReviewAsync.valueOrNull != null
                                      ? 'Update Review'
                                      : 'Submit Review',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DS.s12),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s14,
                  vertical: DS.s12,
                ),
                decoration: BoxDecoration(
                  color: DS.surfaceVariant,
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  border: Border.all(color: DS.border, width: 1),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 15,
                      color: DS.textSecondary,
                    ),
                    SizedBox(width: DS.s8),
                    Expanded(
                      child: Text(
                        'Only enrolled students can rate and review this course.',
                        style: TextStyle(
                          color: DS.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DS.s12),
            ],

            // Review cards
            if (reviews.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: DS.s24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: DS.surfaceVariant,
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                        ),
                        child: const Icon(
                          Icons.rate_review_outlined,
                          color: DS.textHint,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: DS.s12),
                      const Text(
                        'No reviews yet',
                        style: TextStyle(color: DS.textSecondary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...reviews.take(5).map((r) => _ReviewCard(review: r)),
          ],
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final CourseReview review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DS.s10),
      padding: const EdgeInsets.all(DS.s14),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StarRow(rating: review.rating.toDouble(), size: 13),
              const Spacer(),
              Text(
                '${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                style: const TextStyle(color: DS.textHint, fontSize: 11),
              ),
            ],
          ),
          if (review.review != null && review.review!.isNotEmpty) ...[
            const SizedBox(height: DS.s8),
            Text(
              review.review!,
              style: const TextStyle(
                color: DS.textPrimary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const _StarRow({required this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating.floor();
        final half = !filled && i < rating;
        return Icon(
          half ? Icons.star_half_rounded : Icons.star_rounded,
          color: filled || half ? DS.warning : DS.border,
          size: size,
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────
// LECTURES TAB
// ─────────────────────────────────────────────
class _LecturesTab extends ConsumerWidget {
  final AsyncValue<List<Lesson>> lessonsAsync;
  final String courseId;
  const _LecturesTab({required this.lessonsAsync, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnrolled =
        ref.watch(isEnrolledProvider(courseId)).valueOrNull ?? false;
    final enrollmentsAsync = ref.watch(enrollmentsProvider);
    final enrollmentList = enrollmentsAsync.valueOrNull ?? [];
    final enrollment =
        enrollmentList.where((e) => e.courseId == courseId).isNotEmpty
        ? enrollmentList.firstWhere((e) => e.courseId == courseId)
        : null;
    final chaptersAsync = ref.watch(chaptersProvider(courseId));

    return lessonsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
      ),
      error: (_, __) => const Center(
        child: Text(
          'Failed to load lessons',
          style: TextStyle(color: DS.textSecondary),
        ),
      ),
      data: (lessons) {
        if (lessons.isEmpty) {
          return _EmptyTabState(
            icon: Icons.play_circle_outline_rounded,
            message: 'No lessons yet',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(DS.s16),
          children: [
            // Progress card
            if (isEnrolled && enrollment != null) ...[
              Container(
                padding: const EdgeInsets.all(DS.s16),
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
                    Row(
                      children: [
                        const Text(
                          'Your Progress',
                          style: TextStyle(
                            color: DS.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        // Continue button
                        GestureDetector(
                          onTap: () => context.push('/course-player/$courseId'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DS.s12,
                              vertical: DS.s6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF8C38), DS.primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: DS.primary.withOpacity(0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                SizedBox(width: DS.s4),
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DS.s8),
                    Text(
                      '${enrollment.completedLessons} of ${enrollment.courseTotalLessons ?? lessons.length} lessons completed',
                      style: const TextStyle(
                        color: DS.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: DS.s10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: enrollment.progressFraction,
                        minHeight: 8,
                        backgroundColor: DS.border,
                        color: DS.primary,
                      ),
                    ),
                    const SizedBox(height: DS.s6),
                    Row(
                      children: [
                        Text(
                          '${enrollment.progressPercent}% complete',
                          style: const TextStyle(
                            color: DS.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (enrollment.lastLessonTitle != null) ...[
                          const Spacer(),
                          Flexible(
                            child: Text(
                              'Last: ${enrollment.lastLessonTitle}',
                              style: const TextStyle(
                                color: DS.textSecondary,
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DS.s16),
            ],

            // Chapter / lesson list
            chaptersAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => _FlatLessonList(
                lessons: lessons,
                isEnrolled: isEnrolled,
                courseId: courseId,
              ),
              data: (chapters) {
                if (chapters.isEmpty) {
                  return _FlatLessonList(
                    lessons: lessons,
                    isEnrolled: isEnrolled,
                    courseId: courseId,
                  );
                }
                return Column(
                  children: chapters.map((ch) {
                    final chLessons =
                        lessons.where((l) => l.chapterId == ch.id).toList()
                          ..sort((a, b) => a.position.compareTo(b.position));
                    return _ChapterBlock(
                      chapter: ch,
                      lessons: chLessons,
                      isEnrolled: isEnrolled,
                      courseId: courseId,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _FlatLessonList extends StatelessWidget {
  final List<Lesson> lessons;
  final bool isEnrolled;
  final String courseId;
  const _FlatLessonList({
    required this.lessons,
    required this.isEnrolled,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: lessons
        .map(
          (l) =>
              _LessonRow(lesson: l, isEnrolled: isEnrolled, courseId: courseId),
        )
        .toList(),
  );
}

class _ChapterBlock extends StatefulWidget {
  final dynamic chapter;
  final List<Lesson> lessons;
  final bool isEnrolled;
  final String courseId;
  const _ChapterBlock({
    required this.chapter,
    required this.lessons,
    required this.isEnrolled,
    required this.courseId,
  });

  @override
  State<_ChapterBlock> createState() => _ChapterBlockState();
}

class _ChapterBlockState extends State<_ChapterBlock> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s14,
              vertical: DS.s12,
            ),
            decoration: BoxDecoration(
              color: DS.primaryLight,
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(color: DS.primary.withOpacity(0.20), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: DS.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: const Icon(
                    Icons.folder_outlined,
                    color: DS.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: DS.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.chapter.title,
                        style: const TextStyle(
                          color: DS.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        '${widget.lessons.length} lesson${widget.lessons.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: DS.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: DS.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(left: DS.s12),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: DS.primary.withOpacity(0.20), width: 2),
              ),
            ),
            child: Column(
              children: widget.lessons
                  .map(
                    (l) => _LessonRow(
                      lesson: l,
                      isEnrolled: widget.isEnrolled,
                      courseId: widget.courseId,
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: DS.s10),
      ],
    );
  }
}

class _LessonRow extends StatelessWidget {
  final Lesson lesson;
  final bool isEnrolled;
  final String courseId;
  const _LessonRow({
    required this.lesson,
    required this.isEnrolled,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    final canPlay = isEnrolled || lesson.isFreePreview;
    final isVideo = lesson.type == 'video';

    return InkWell(
      onTap: canPlay
          ? () => context.push('/course-player/$courseId?lessonId=${lesson.id}')
          : null,
      borderRadius: BorderRadius.circular(DS.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DS.s8, horizontal: DS.s8),
        child: Row(
          children: [
            // Icon tile
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: canPlay
                    ? (isVideo ? DS.primaryLight : DS.indigo.withOpacity(0.10))
                    : DS.surfaceVariant,
                borderRadius: BorderRadius.circular(DS.radiusSm),
              ),
              child: Icon(
                isVideo ? Icons.play_arrow_rounded : Icons.description_outlined,
                color: canPlay
                    ? (isVideo ? DS.primary : DS.indigo)
                    : DS.textHint,
                size: 18,
              ),
            ),
            const SizedBox(width: DS.s12),

            // Title + duration
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: TextStyle(
                      color: canPlay ? DS.textPrimary : DS.textHint,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DS.s2),
                  Text(
                    '${lesson.durationMin} min',
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),

            // Badge / lock
            if (lesson.isFreePreview)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s8,
                  vertical: DS.s4,
                ),
                decoration: BoxDecoration(
                  color: DS.success.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: DS.success.withOpacity(0.25)),
                ),
                child: const Text(
                  'Free',
                  style: TextStyle(
                    color: DS.success,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Icon(
                isEnrolled
                    ? Icons.play_circle_outline_rounded
                    : Icons.lock_outline_rounded,
                color: isEnrolled ? DS.primary : DS.textHint,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TESTS TAB
// ─────────────────────────────────────────────
class _TestsTab extends ConsumerWidget {
  final String courseId;
  const _TestsTab({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testsAsync = ref.watch(courseTestsProvider(courseId));
    final isEnrolled =
        ref.watch(isEnrolledProvider(courseId)).valueOrNull ?? false;

    return testsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
      ),
      error: (_, __) => const Center(
        child: Text(
          'Failed to load tests',
          style: TextStyle(color: DS.textSecondary),
        ),
      ),
      data: (tests) {
        if (tests.isEmpty) {
          return _EmptyTabState(
            icon: Icons.quiz_outlined,
            message: 'No tests for this course yet',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(DS.s16),
          itemCount: tests.length,
          separatorBuilder: (_, __) => const SizedBox(height: DS.s10),
          itemBuilder: (_, i) {
            final t = tests[i];
            return Container(
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: DS.primaryLight,
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: DS.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: DS.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: const TextStyle(
                            color: DS.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: DS.s4),
                        Row(
                          children: [
                            _TestChip(label: t.testType.toUpperCase()),
                            const SizedBox(width: DS.s6),
                            _TestChip(label: '${t.durationMinutes} min'),
                            const SizedBox(width: DS.s6),
                            _TestChip(label: '${t.totalQuestions} Qs'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: DS.s8),
                  GestureDetector(
                    onTap: isEnrolled
                        ? () => context.push('/test/${t.id}')
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Enroll in this course to take tests.',
                              ),
                            ),
                          ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DS.s12,
                        vertical: DS.s8,
                      ),
                      decoration: BoxDecoration(
                        color: isEnrolled ? DS.primary : DS.surfaceVariant,
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: Text(
                        isEnrolled ? 'Start' : 'Locked',
                        style: TextStyle(
                          color: isEnrolled ? Colors.white : DS.textHint,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TestChip extends StatelessWidget {
  final String label;
  const _TestChip({required this.label});

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
// PDF NOTES TAB
// ─────────────────────────────────────────────
class _PdfsTab extends ConsumerWidget {
  final AsyncValue<List<CoursePdf>> pdfsAsync;
  final String courseId;
  const _PdfsTab({required this.pdfsAsync, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEnrolled =
        ref.watch(isEnrolledProvider(courseId)).valueOrNull ?? false;

    return pdfsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
      ),
      error: (_, __) => const Center(
        child: Text(
          'Failed to load PDFs',
          style: TextStyle(color: DS.textSecondary),
        ),
      ),
      data: (pdfs) {
        if (pdfs.isEmpty) {
          return _EmptyTabState(
            icon: Icons.picture_as_pdf_outlined,
            message: 'No PDF notes yet',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(DS.s16),
          itemCount: pdfs.length,
          separatorBuilder: (_, __) => const SizedBox(height: DS.s10),
          itemBuilder: (_, i) {
            final pdf = pdfs[i];
            final sizeKb = pdf.sizeBytes != null
                ? '${(pdf.sizeBytes! / 1024).toStringAsFixed(0)} KB'
                : '';

            return InkWell(
              onTap: isEnrolled
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(
                          title: pdf.title,
                          fileUrl: pdf.fileUrl,
                        ),
                      ),
                    )
                  : null,
              borderRadius: BorderRadius.circular(DS.radiusMd),
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
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: DS.errorSurface,
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: DS.error,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: DS.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pdf.title,
                            style: TextStyle(
                              color: isEnrolled ? DS.textPrimary : DS.textHint,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          if (sizeKb.isNotEmpty)
                            Text(
                              sizeKb,
                              style: const TextStyle(
                                color: DS.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: DS.s8),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isEnrolled ? DS.primaryLight : DS.surfaceVariant,
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: Icon(
                        isEnrolled
                            ? Icons.download_outlined
                            : Icons.lock_outline_rounded,
                        color: isEnrolled ? DS.primary : DS.textHint,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// TIME TAB
// ─────────────────────────────────────────────
class _TimeTab extends StatelessWidget {
  final Course course;
  const _TimeTab({required this.course});

  @override
  Widget build(BuildContext context) {
    final items = [
      _TimeItem(
        Icons.schedule_rounded,
        'Total Duration',
        '${course.durationHours ?? 0} hours',
        DS.primary,
      ),
      _TimeItem(
        Icons.play_circle_outline_rounded,
        'Total Lectures',
        '${course.totalLessons ?? 0} lessons',
        DS.indigo,
      ),
      _TimeItem(
        Icons.all_inclusive_rounded,
        'Access',
        'Lifetime access',
        DS.success,
      ),
      _TimeItem(
        Icons.workspace_premium_outlined,
        'Certificate',
        'Certificate of completion',
        DS.warning,
      ),
      _TimeItem(
        Icons.replay_rounded,
        'Money-back',
        '7-day guarantee',
        DS.error,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(DS.s16),
      children: [
        Container(
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
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s16,
                      vertical: DS.s14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                          ),
                          child: Icon(item.icon, color: item.color, size: 18),
                        ),
                        const SizedBox(width: DS.s12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: const TextStyle(
                              color: DS.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          item.value,
                          style: const TextStyle(
                            color: DS.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      color: DS.border,
                      indent: DS.s16,
                      endIndent: DS.s16,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _TimeItem {
  final IconData icon;
  final String label, value;
  final Color color;
  const _TimeItem(this.icon, this.label, this.value, this.color);
}

// ─────────────────────────────────────────────
// ENROLL BAR
// ─────────────────────────────────────────────
class _EnrollBar extends ConsumerStatefulWidget {
  final Course course;
  final String courseId;
  const _EnrollBar({required this.course, required this.courseId});

  @override
  ConsumerState<_EnrollBar> createState() => _EnrollBarState();
}

class _EnrollBarState extends ConsumerState<_EnrollBar> {
  final _rzp = RazorpayService();
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _rzp.init(
      onSuccess: _onPaymentSuccess,
      onFailure: _onPaymentFailure,
      onExternalWallet: _onExternalWallet,
    );
  }

  @override
  void dispose() {
    _rzp.dispose();
    super.dispose();
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _processing = true);
    try {
      await ref
          .read(enrollmentsRepositoryProvider)
          .enrollInCourse(widget.courseId);
      ref.invalidate(isEnrolledProvider(widget.courseId));
      ref.invalidate(enrollmentsProvider);
      if (mounted) _showSuccessSheet();
    } catch (e) {
      if (mounted)
        _showSnack('Enrollment failed. Contact support.', error: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _onPaymentFailure(PaymentFailureResponse response) {
    _showSnack(
      'Payment failed: ${response.message ?? 'Unknown error'}',
      error: true,
    );
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _showSnack('External wallet selected: ${response.walletName}');
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? DS.error : DS.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startPayment() {
    final user = SupabaseService.client.auth.currentUser;
    if (widget.course.isFree) {
      // Free course — enroll directly without payment
      _onPaymentSuccess(PaymentSuccessResponse(null, null, null, null));
      return;
    }
    _rzp.openCheckout(
      amountInRupees: widget.course.price,
      courseId: widget.courseId,
      courseName: widget.course.title,
      userEmail: user?.email,
      userName: user?.userMetadata?['full_name'] as String?,
      userPhone: user?.phone,
    );
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DS.surface,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusXl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(DS.s24, DS.s28, DS.s24, DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: DS.successSurface,
                borderRadius: BorderRadius.circular(DS.radiusLg),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 40,
                color: DS.success,
              ),
            ),
            const SizedBox(height: DS.s20),
            const Text(
              'Enrollment Successful!',
              style: TextStyle(
                color: DS.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: DS.s8),
            Text(
              'You are now enrolled in ${widget.course.title}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: DS.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DS.s24),
            SizedBox(
              width: double.infinity,
              height: 50,
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
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/course-player/${widget.courseId}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'Start Learning',
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

  @override
  Widget build(BuildContext context) {
    final isEnrolled =
        ref.watch(isEnrolledProvider(widget.courseId)).valueOrNull ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(
        DS.s16,
        DS.s12,
        DS.s16,
        DS.s12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(top: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: isEnrolled
          ? SizedBox(
              width: double.infinity,
              height: 52,
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
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () =>
                      context.push('/course-player/${widget.courseId}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text(
                    'Continue Learning',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            )
          : Row(
              children: [
                // Price
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.course.isFree
                          ? 'Free'
                          : '₹${widget.course.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: DS.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: DS.s16),

                // Enroll / Pay button
                Expanded(
                  child: SizedBox(
                    height: 52,
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
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _processing ? null : _startPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DS.radiusMd),
                          ),
                        ),
                        child: _processing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    widget.course.isFree
                                        ? Icons.school_rounded
                                        : Icons.payment_rounded,
                                    size: 20,
                                  ),
                                  const SizedBox(width: DS.s8),
                                  Text(
                                    widget.course.isFree
                                        ? 'Enroll Free'
                                        : 'Pay & Enroll',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
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

// ─────────────────────────────────────────────
// SHARED: EMPTY TAB STATE
// ─────────────────────────────────────────────
class _EmptyTabState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyTabState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DS.surfaceVariant,
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
            child: Icon(icon, color: DS.textHint, size: 30),
          ),
          const SizedBox(height: DS.s14),
          Text(
            message,
            style: const TextStyle(color: DS.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED: ERROR STATE
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

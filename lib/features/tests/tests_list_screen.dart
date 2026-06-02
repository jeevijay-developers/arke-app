import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'data/tests_providers.dart';
import 'data/models/app_test.dart';

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
// TESTS LIST SCREEN
// ─────────────────────────────────────────────
class TestsListScreen extends ConsumerStatefulWidget {
  const TestsListScreen({super.key});

  @override
  ConsumerState<TestsListScreen> createState() => _TestsListScreenState();
}

class _TestsListScreenState extends ConsumerState<TestsListScreen>
    with SingleTickerProviderStateMixin {
  String? _sortSubject;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  List<AppTest> _filtered(List<AppTest> tests) {
    if (_sortSubject == null) return List<AppTest>.from(tests);
    return tests.where((t) => t.subject == _sortSubject).toList();
  }

  void _showFilterSheet(List<AppTest> tests) {
    final subjects = tests.map((t) => t.subject).toSet().toList()..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: DS.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusXl)),
      ),
      builder: (_) => _FilterSheet(
        subjects: subjects,
        selected: _sortSubject,
        onSelect: (s) {
          setState(() => _sortSubject = s);
          Navigator.pop(context);
        },
        onClear: () {
          setState(() => _sortSubject = null);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final testsAsync = ref.watch(accessibleTestsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/student-dashboard');
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: testsAsync.when(
          loading: () => const _LoadingState(),
          error: (e, _) => _ErrorState(message: 'Failed to load: $e'),
          data: (tests) {
            final now = DateTime.now();
            final courseTests = _filtered(
              tests
                  .where(
                    (t) =>
                        t.courseId != null &&
                        (t.endsAt == null || t.endsAt!.isAfter(now)),
                  )
                  .toList(),
            );
            final freeTests = _filtered(
              tests
                  .where(
                    (t) =>
                        t.courseId == null &&
                        (t.endsAt == null || t.endsAt!.isAfter(now)),
                  )
                  .toList(),
            );

            return Column(
              children: [
                // ── Custom header ──
                _TestsHeader(
                  totalTests: tests.length,
                  sortSubject: _sortSubject,
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/student-dashboard'),
                  onFilter: () => _showFilterSheet(tests),
                  tabCtrl: _tabCtrl,
                ),

                // ── Active filter chip ──
                if (_sortSubject != null)
                  _ActiveFilterBanner(
                    subject: _sortSubject!,
                    count: courseTests.length + freeTests.length,
                    onClear: () => setState(() => _sortSubject = null),
                  ),

                // ── Tab content ──
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _TestList(
                        tests: courseTests,
                        emptyMessage: _sortSubject != null
                            ? 'No $_sortSubject course tests'
                            : 'No course tests found.\nEnroll in a course to see its tests.',
                        emptyIcon: Icons.menu_book_outlined,
                        sortSubject: _sortSubject,
                        onClearFilter: () =>
                            setState(() => _sortSubject = null),
                        onStart: (id) => context.push('/test/$id'),
                      ),
                      _TestList(
                        tests: freeTests,
                        emptyMessage: _sortSubject != null
                            ? 'No $_sortSubject free tests'
                            : 'No free standalone tests available.',
                        emptyIcon: Icons.quiz_outlined,
                        sortSubject: _sortSubject,
                        onClearFilter: () =>
                            setState(() => _sortSubject = null),
                        onStart: (id) => context.push('/test/$id'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────
// CUSTOM HEADER
// ─────────────────────────────────────────────
class _TestsHeader extends StatelessWidget {
  final int totalTests;
  final String? sortSubject;
  final VoidCallback onBack;
  final VoidCallback onFilter;
  final TabController tabCtrl;

  const _TestsHeader({
    required this.totalTests,
    required this.sortSubject,
    required this.onBack,
    required this.onFilter,
    required this.tabCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(DS.s8, DS.s8, DS.s12, DS.s16),
              child: Row(
                children: [
                  // Back
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

                  // Title + count
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '$totalTests tests available',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Filter button
                  GestureDetector(
                    onTap: onFilter,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        if (sortSubject != null)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: DS.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: DS.primary,
                                  width: 1.5,
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(1.5),
                                decoration: const BoxDecoration(
                                  color: DS.primary,
                                  shape: BoxShape.circle,
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

            // ── Tab bar ──
            TabBar(
              controller: tabCtrl,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white.withOpacity(0.60),
              indicatorColor: Colors.white,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              labelStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_outlined, size: 14),
                      SizedBox(width: DS.s6),
                      Text('Course Tests'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.quiz_outlined, size: 14),
                      SizedBox(width: DS.s6),
                      Text('Free Tests'),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: DS.s4),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACTIVE FILTER BANNER
// ─────────────────────────────────────────────
class _ActiveFilterBanner extends StatelessWidget {
  final String subject;
  final int count;
  final VoidCallback onClear;

  const _ActiveFilterBanner({
    required this.subject,
    required this.count,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s12, DS.s16, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s10,
              vertical: DS.s6,
            ),
            decoration: BoxDecoration(
              color: DS.primaryLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: DS.primary.withOpacity(0.25), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.filter_list_rounded,
                  size: 12,
                  color: DS.primary,
                ),
                const SizedBox(width: DS.s4),
                Text(
                  subject,
                  style: const TextStyle(
                    color: DS.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: DS.s6),
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: DS.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DS.s8),
          Text(
            '$count result${count == 1 ? '' : 's'}',
            style: const TextStyle(color: DS.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TEST LIST
// ─────────────────────────────────────────────
class _TestList extends StatelessWidget {
  final List<AppTest> tests;
  final String emptyMessage;
  final IconData emptyIcon;
  final String? sortSubject;
  final VoidCallback onClearFilter;
  final void Function(String id) onStart;

  const _TestList({
    required this.tests,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.sortSubject,
    required this.onClearFilter,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) {
      return _EmptyTab(
        icon: emptyIcon,
        message: emptyMessage,
        showClear: sortSubject != null,
        onClearFilter: onClearFilter,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s32),
      itemCount: tests.length,
      separatorBuilder: (_, __) => const SizedBox(height: DS.s12),
      itemBuilder: (_, i) => _TestCard(
        test: tests[i],
        index: i,
        onStart: () {
          HapticFeedback.mediumImpact();
          onStart(tests[i].id);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TEST CARD
// ─────────────────────────────────────────────
class _TestCard extends StatelessWidget {
  final AppTest test;
  final int index;
  final VoidCallback onStart;

  const _TestCard({
    required this.test,
    required this.index,
    required this.onStart,
  });

  static const _accentColors = [
    DS.primary,
    DS.indigo,
    DS.success,
    DS.warning,
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
  ];

  Color get _accent => _accentColors[index % _accentColors.length];

  // Difficulty → color mapping
  Color _diffColor(String difficulty) {
    final lower = difficulty.toLowerCase();
    if (lower.contains('jee') || lower.contains('advanced')) return DS.indigo;
    if (lower.contains('neet')) return DS.success;
    if (lower.contains('easy')) return DS.success;
    if (lower.contains('hard') || lower.contains('difficult')) return DS.error;
    return DS.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final t = test;

    return Container(
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
          // ── Accent top bar ──
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
            padding: const EdgeInsets.all(DS.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header chips row ──
                Row(
                  children: [
                    // Subject chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DS.s8,
                        vertical: DS.s4,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        t.subject,
                        style: TextStyle(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: DS.s6),

                    // Difficulty badge
                    _DifficultyBadge(difficulty: t.examPattern),

                    const Spacer(),

                    // Test type chip
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
                        t.testType,
                        style: const TextStyle(
                          color: DS.textSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: DS.s12),

                // ── Title ──
                Text(
                  t.title,
                  style: const TextStyle(
                    color: DS.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1.3,
                  ),
                ),

                // ── Description ──
                if (t.description != null && t.description!.isNotEmpty) ...[
                  const SizedBox(height: DS.s6),
                  Text(
                    t.description!,
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: DS.s14),

                // ── Meta row ──
                Row(
                  children: [
                    _MetaTile(
                      icon: Icons.schedule_rounded,
                      label: '${t.durationMinutes} min',
                      color: _accent,
                    ),
                    const SizedBox(width: DS.s8),
                    _MetaTile(
                      icon: Icons.help_outline_rounded,
                      label: '${t.totalQuestions} Qs',
                      color: DS.indigo,
                    ),
                    const SizedBox(width: DS.s8),
                    _MetaTile(
                      icon: Icons.grade_outlined,
                      label: '${t.totalMarks.toStringAsFixed(0)} marks',
                      color: DS.success,
                    ),
                    const Spacer(),

                    // Start button
                    GestureDetector(
                      onTap: onStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DS.s16,
                          vertical: DS.s8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_accent.withOpacity(0.80), _accent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(0.28),
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
                              size: 16,
                            ),
                            SizedBox(width: DS.s4),
                            Text(
                              'Start',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
// META TILE
// ─────────────────────────────────────────────
class _MetaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaTile({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(DS.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: DS.s4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DIFFICULTY BADGE
// ─────────────────────────────────────────────
class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge({required this.difficulty});

  Color get _color {
    final lower = difficulty.toLowerCase();
    if (lower.contains('jee') || lower.contains('advanced')) return DS.indigo;
    if (lower.contains('neet')) return DS.success;
    if (lower.contains('easy')) return DS.success;
    if (lower.contains('hard') || lower.contains('difficult')) return DS.error;
    return DS.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _color.withOpacity(0.20), width: 1),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: _color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FILTER BOTTOM SHEET
// ─────────────────────────────────────────────
class _FilterSheet extends StatelessWidget {
  final List<String> subjects;
  final String? selected;
  final void Function(String?) onSelect;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.subjects,
    required this.selected,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DS.s24, DS.s20, DS.s24, DS.s28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DS.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: DS.s16),

          // Title row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DS.primaryLight,
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: DS.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: DS.s12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter by Subject',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: DS.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Select a subject to filter tests',
                      style: TextStyle(fontSize: 12, color: DS.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected != null)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s10,
                      vertical: DS.s6,
                    ),
                    decoration: BoxDecoration(
                      color: DS.errorSurface,
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        color: DS.error,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: DS.s20),

          // Subject chips
          Wrap(
            spacing: DS.s8,
            runSpacing: DS.s8,
            children: [
              // All chip
              _SubjectChip(
                label: 'All Subjects',
                selected: selected == null,
                onTap: () => onSelect(null),
              ),
              ...subjects.map(
                (s) => _SubjectChip(
                  label: s,
                  selected: selected == s,
                  onTap: () => onSelect(s),
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
// SUBJECT CHIP
// ─────────────────────────────────────────────
class _SubjectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: DS.s14,
          vertical: DS.s8,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF8C38), DS.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : DS.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? DS.primary : DS.border,
            width: selected ? 0 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: DS.primary.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 13),
              const SizedBox(width: DS.s4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : DS.textPrimary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY TAB
// ─────────────────────────────────────────────
class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool showClear;
  final VoidCallback onClearFilter;

  const _EmptyTab({
    required this.icon,
    required this.message,
    required this.showClear,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
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
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: DS.s20),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DS.textPrimary,
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
            ),
            if (showClear) ...[
              const SizedBox(height: DS.s20),
              GestureDetector(
                onTap: onClearFilter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s20,
                    vertical: DS.s10,
                  ),
                  decoration: BoxDecoration(
                    color: DS.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: DS.primary.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list_off_rounded,
                        size: 15,
                        color: DS.primary,
                      ),
                      SizedBox(width: DS.s6),
                      Text(
                        'Clear filter',
                        style: TextStyle(
                          color: DS.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOADING STATE
// ─────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: DS.background,
      body: Center(
        child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
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
    return Scaffold(
      backgroundColor: DS.background,
      body: Center(
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
      ),
    );
  }
}

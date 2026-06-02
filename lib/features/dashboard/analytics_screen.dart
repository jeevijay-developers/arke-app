import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  static const warningSurface = Color(0xFFFFFBEB);
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
// DATA MODELS
// ─────────────────────────────────────────────
class _AnalyticsData {
  final int testsTaken;
  final double avgScore;
  final double bestScore;
  final double accuracy;
  final int streak;
  final Map<String, double> subjectScores;
  final List<_AttemptRow> recentAttempts;

  const _AnalyticsData({
    required this.testsTaken,
    required this.avgScore,
    required this.bestScore,
    required this.accuracy,
    required this.streak,
    required this.subjectScores,
    required this.recentAttempts,
  });
}

class _AttemptRow {
  final String testName;
  final int score, total, percentage;
  final DateTime attemptedAt;

  const _AttemptRow({
    required this.testName,
    required this.score,
    required this.total,
    required this.percentage,
    required this.attemptedAt,
  });
}

// ─────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────
final _analyticsProvider = FutureProvider.autoDispose<_AnalyticsData>((
  ref,
) async {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return _empty();

  final data = await client
      .from('test_attempts')
      .select(
        'id, test_id, test_name, subject, score, total_questions, '
        'correct_answers, percentile, time_spent_seconds, '
        'attempted_at, created_at',
      )
      .eq('user_id', userId)
      .order('created_at', ascending: false);

  final rows = data as List;
  if (rows.isEmpty) return _empty();

  final attempts = rows.map((r) {
    final total = (r['total_questions'] as num?)?.toInt() ?? 0;
    final correct = (r['correct_answers'] as num?)?.toInt() ?? 0;
    final pct =
        (r['percentile'] as num?)?.round() ??
        (r['score'] as num?)?.round() ??
        (total == 0 ? 0 : (correct * 100 / total).round());
    final dateStr =
        r['attempted_at']?.toString() ?? r['created_at']?.toString() ?? '';
    return _AttemptRow(
      testName: r['test_name'] as String? ?? 'Test',
      score: correct,
      total: total,
      percentage: pct,
      attemptedAt: dateStr.isNotEmpty
          ? (DateTime.tryParse(dateStr)?.toLocal() ??
             DateTime.tryParse('${dateStr}Z')?.toLocal() ??
             DateTime.now())
          : DateTime.now(),
    );
  }).toList();

  final percentages = attempts.map((a) => a.percentage.toDouble()).toList();
  final avgScore = percentages.reduce((a, b) => a + b) / percentages.length;
  final bestScore = percentages.reduce((a, b) => a > b ? a : b);

  final totalCorrect = attempts.fold<int>(0, (s, a) => s + a.score);
  final totalQs = attempts.fold<int>(0, (s, a) => s + a.total);
  final accuracy = totalQs == 0 ? 0.0 : (totalCorrect / totalQs) * 100;

  // Streak: consecutive days with at least one attempt
  final days =
      attempts
          .map((a) {
            final d = a.attemptedAt.toLocal();
            return DateTime(d.year, d.month, d.day);
          })
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

  int streak = 0;
  DateTime expected = DateTime.now();
  expected = DateTime(expected.year, expected.month, expected.day);
  for (final d in days) {
    final diff = expected.difference(d).inDays;
    if (diff == 0 || diff == 1) {
      streak++;
      expected = d.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }

  Map<String, double> subjectScores = {};
  try {
    final subjectTotals = <String, List<int>>{};
    for (final r in rows) {
      final subject = r['subject'] as String?;
      if (subject == null || subject.isEmpty) continue;
      final total = (r['total_questions'] as num?)?.toInt() ?? 0;
      final correct = (r['correct_answers'] as num?)?.toInt() ?? 0;
      final pct =
          (r['percentile'] as num?)?.round() ??
          (r['score'] as num?)?.round() ??
          (total == 0 ? 0 : (correct * 100 / total).round());
      subjectTotals.putIfAbsent(subject, () => []).add(pct);
    }
    subjectScores = subjectTotals.map(
      (s, vals) => MapEntry(s, vals.reduce((a, b) => a + b) / vals.length),
    );
  } catch (_) {}

  return _AnalyticsData(
    testsTaken: attempts.length,
    avgScore: avgScore,
    bestScore: bestScore,
    accuracy: accuracy,
    streak: streak,
    subjectScores: subjectScores,
    recentAttempts: attempts.take(5).toList(),
  );
});

_AnalyticsData _empty() => const _AnalyticsData(
  testsTaken: 0,
  avgScore: 0,
  bestScore: 0,
  accuracy: 0,
  streak: 0,
  subjectScores: {},
  recentAttempts: [],
);

// ─────────────────────────────────────────────
// ANALYTICS SCREEN
// ─────────────────────────────────────────────
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_analyticsProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: async.when(
          loading: () => const _LoadingState(),
          error: (e, _) =>
              _ErrorState(onRetry: () => ref.invalidate(_analyticsProvider)),
          data: (d) => d.testsTaken == 0
              ? _EmptyState()
              : _AnalyticsBody(
                  d: d,
                  onBack: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                  onRefresh: () => ref.invalidate(_analyticsProvider),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ANALYTICS BODY
// ─────────────────────────────────────────────
class _AnalyticsBody extends StatelessWidget {
  final _AnalyticsData d;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _AnalyticsBody({
    required this.d,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Orange hero header ──
        SliverToBoxAdapter(
          child: _HeroHeader(d: d, onBack: onBack, onRefresh: onRefresh),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(DS.s16, DS.s24, DS.s16, DS.s32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // ── Metrics grid ──
              _MetricsGrid(data: d),
              const SizedBox(height: DS.s24),

              // ── Score trend mini-chart ──
              if (d.recentAttempts.length > 1) ...[
                _SectionHeader(
                  title: 'Score Trend',
                  icon: Icons.show_chart_rounded,
                  color: DS.indigo,
                ),
                const SizedBox(height: DS.s12),
                _ScoreTrendChart(attempts: d.recentAttempts.reversed.toList()),
                const SizedBox(height: DS.s24),
              ],

              // ── Performance summary ──
              _SectionHeader(
                title: 'Performance Summary',
                icon: Icons.analytics_outlined,
                color: DS.primary,
              ),
              const SizedBox(height: DS.s12),
              _PerformanceSummaryCard(data: d),
              const SizedBox(height: DS.s24),

              // ── Subject breakdown ──
              if (d.subjectScores.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Subject Breakdown',
                  icon: Icons.book_outlined,
                  color: DS.success,
                ),
                const SizedBox(height: DS.s12),
                ...d.subjectScores.entries.toList().asMap().entries.map(
                  (e) => _SubjectBar(
                    index: e.key,
                    subject: e.value.key,
                    score: e.value.value,
                  ),
                ),
                const SizedBox(height: DS.s24),
              ],

              // ── Recent attempts ──
              _SectionHeader(
                title: 'Recent Attempts',
                icon: Icons.history_rounded,
                color: DS.warning,
              ),
              const SizedBox(height: DS.s12),
              ...d.recentAttempts.asMap().entries.map(
                (e) => _AttemptCard(index: e.key, attempt: e.value),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final _AnalyticsData d;
  final VoidCallback onBack;
  final VoidCallback onRefresh;

  const _HeroHeader({
    required this.d,
    required this.onBack,
    required this.onRefresh,
  });

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
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DS.s20,
                DS.s12,
                DS.s20,
                DS.s28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top bar ──
                  Row(
                    children: [
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
                      const Expanded(
                        child: Text(
                          'My Analytics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: DS.s24),

                  // ── Avg score highlight ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Average Score',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: DS.s4),
                          Text(
                            '${d.avgScore.round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              letterSpacing: -2,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Accuracy ring
                      Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.30),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${d.accuracy.round()}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  'Accuracy',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.70),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: DS.s20),

                  // ── Summary pills ──
                  Row(
                    children: [
                      _HeroPill(
                        icon: Icons.assignment_turned_in_outlined,
                        label: '${d.testsTaken} Tests',
                      ),
                      const SizedBox(width: DS.s8),
                      _HeroPill(
                        icon: Icons.emoji_events_outlined,
                        label: 'Best ${d.bestScore.round()}%',
                      ),
                      const SizedBox(width: DS.s8),
                      _HeroPill(
                        icon: Icons.local_fire_department_rounded,
                        label: '${d.streak}d Streak',
                      ),
                    ],
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
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          top: 30,
          right: 30,
          child: Container(
            width: 55,
            height: 55,
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

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroPill({required this.icon, required this.label});

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
// METRICS GRID
// ─────────────────────────────────────────────
class _MetricsGrid extends StatelessWidget {
  final _AnalyticsData data;
  const _MetricsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        icon: Icons.assignment_turned_in_outlined,
        label: 'Tests Taken',
        value: '${data.testsTaken}',
        color: DS.primary,
        sub: 'Total attempts',
      ),
      _MetricData(
        icon: Icons.show_chart_rounded,
        label: 'Avg Score',
        value: '${data.avgScore.round()}%',
        color: DS.success,
        sub: 'Across all tests',
      ),
      _MetricData(
        icon: Icons.emoji_events_outlined,
        label: 'Best Score',
        value: '${data.bestScore.round()}%',
        color: DS.warning,
        sub: 'Personal best',
      ),
      _MetricData(
        icon: Icons.local_fire_department_rounded,
        label: 'Day Streak',
        value: '${data.streak}d',
        color: DS.error,
        sub: 'Keep it going!',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.60,
        crossAxisSpacing: DS.s12,
        mainAxisSpacing: DS.s12,
      ),
      itemBuilder: (_, i) => _MetricCard(data: metrics[i]),
    );
  }
}

class _MetricData {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  const _MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.sub,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});

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
            width: 42,
            height: 42,
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
                  style: TextStyle(
                    color: data.color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: DS.s2),
                Text(
                  data.label,
                  style: const TextStyle(
                    color: DS.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  data.sub,
                  style: const TextStyle(color: DS.textHint, fontSize: 10),
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
// SCORE TREND CHART (Custom Bar Chart)
// ─────────────────────────────────────────────
class _ScoreTrendChart extends StatelessWidget {
  final List<_AttemptRow> attempts;
  const _ScoreTrendChart({required this.attempts});

  Color _barColor(int pct) {
    if (pct >= 80) return DS.success;
    if (pct >= 60) return DS.primary;
    if (pct >= 40) return DS.warning;
    return DS.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
                'Last 5 Attempts',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: DS.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s8,
                  vertical: DS.s4,
                ),
                decoration: BoxDecoration(
                  color: DS.indigoLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Score %',
                  style: TextStyle(
                    color: DS.indigo,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: DS.s20),

          // Bar chart
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: attempts.take(5).toList().asMap().entries.map((e) {
                final a = e.value;
                final barH = (a.percentage / 100) * 100;
                final color = _barColor(a.percentage);
                final isLast = e.key == attempts.take(5).length - 1;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: isLast ? 0 : DS.s8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${a.percentage}%',
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: DS.s4),
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(DS.s6),
                          ),
                          child: Container(
                            height: barH.clamp(8.0, 80.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color.withOpacity(0.60), color],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: DS.s10),
          const Divider(color: DS.border, height: 1),
          const SizedBox(height: DS.s10),

          // X-axis labels
          Row(
            children: attempts.take(5).toList().asMap().entries.map((e) {
              final d = e.value.attemptedAt;
              final label = '${d.day}/${d.month}';
              final isLast = e.key == attempts.take(5).length - 1;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : DS.s8),
                  child: Text(
                    label,
                    style: const TextStyle(color: DS.textHint, fontSize: 9.5),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PERFORMANCE SUMMARY CARD
// ─────────────────────────────────────────────
class _PerformanceSummaryCard extends StatelessWidget {
  final _AnalyticsData data;
  const _PerformanceSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _PerfData(
        'Average Score',
        '${data.avgScore.round()}%',
        DS.primary,
        Icons.show_chart_rounded,
      ),
      _PerfData(
        'Best Score',
        '${data.bestScore.round()}%',
        DS.success,
        Icons.emoji_events_outlined,
      ),
      _PerfData(
        'Accuracy',
        '${data.accuracy.round()}%',
        DS.warning,
        Icons.gps_fixed_rounded,
      ),
      _PerfData(
        'Tests Taken',
        '${data.testsTaken}',
        DS.indigo,
        Icons.assignment_turned_in_outlined,
      ),
      _PerfData(
        'Day Streak',
        '${data.streak} days',
        DS.error,
        Icons.local_fire_department_rounded,
      ),
    ];

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
        children: rows.asMap().entries.map((e) {
          final row = e.value;
          final isLast = e.key == rows.length - 1;
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
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: row.color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: Icon(row.icon, color: row.color, size: 18),
                    ),
                    const SizedBox(width: DS.s12),
                    Expanded(
                      child: Text(
                        row.label,
                        style: const TextStyle(
                          color: DS.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      row.value,
                      style: TextStyle(
                        color: row.color,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  color: DS.border,
                  indent: DS.s16,
                  endIndent: DS.s16,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _PerfData {
  final String label, value;
  final Color color;
  final IconData icon;
  const _PerfData(this.label, this.value, this.color, this.icon);
}

// ─────────────────────────────────────────────
// SUBJECT BAR
// ─────────────────────────────────────────────
class _SubjectBar extends StatelessWidget {
  final int index;
  final String subject;
  final double score;

  const _SubjectBar({
    required this.index,
    required this.subject,
    required this.score,
  });

  static const _icons = [
    Icons.science_outlined,
    Icons.biotech_outlined,
    Icons.calculate_outlined,
    Icons.history_edu_outlined,
    Icons.language_outlined,
    Icons.computer_outlined,
    Icons.public_outlined,
    Icons.attach_money_outlined,
  ];

  Color get _barColor {
    final pct = score;
    if (pct >= 80) return DS.success;
    if (pct >= 60) return DS.primary;
    if (pct >= 40) return DS.warning;
    return DS.error;
  }

  Color get _barSurface {
    final pct = score;
    if (pct >= 80) return DS.successSurface;
    if (pct >= 60) return DS.primaryLight;
    if (pct >= 40) return DS.warningSurface;
    return DS.errorSurface;
  }

  @override
  Widget build(BuildContext context) {
    final pct = score.clamp(0.0, 100.0);
    final pctInt = pct.round();
    final icon = _icons[index % _icons.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s10),
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
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _barSurface,
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: Icon(icon, size: 18, color: _barColor),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: Text(
                    subject,
                    style: const TextStyle(
                      color: DS.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Score badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s10,
                    vertical: DS.s4,
                  ),
                  decoration: BoxDecoration(
                    color: _barColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _barColor.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$pctInt%',
                    style: TextStyle(
                      color: _barColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DS.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 8,
                backgroundColor: DS.border,
                color: _barColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ATTEMPT CARD
// ─────────────────────────────────────────────
class _AttemptCard extends StatelessWidget {
  final int index;
  final _AttemptRow attempt;

  const _AttemptCard({required this.index, required this.attempt});

  Color get _color {
    if (attempt.percentage >= 70) return DS.success;
    if (attempt.percentage >= 40) return DS.warning;
    return DS.error;
  }

  IconData get _icon {
    if (attempt.percentage >= 70) return Icons.trending_up_rounded;
    if (attempt.percentage >= 40) return Icons.trending_flat_rounded;
    return Icons.trending_down_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s10),
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
            // Score circle
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.10),
                shape: BoxShape.circle,
                border: Border.all(color: _color.withOpacity(0.25), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${attempt.percentage}%',
                    style: TextStyle(
                      color: _color,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DS.s12),

            // Test info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attempt.testName,
                    style: const TextStyle(
                      color: DS.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DS.s4),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 12,
                        color: DS.textHint,
                      ),
                      const SizedBox(width: DS.s4),
                      Text(
                        '${attempt.score}/${attempt.total} correct',
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

            const SizedBox(width: DS.s8),

            // Trend icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(DS.radiusSm),
              ),
              child: Icon(_icon, color: _color, size: 16),
            ),
          ],
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(DS.radiusSm),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: DS.s10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DS.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
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
    return Scaffold(
      backgroundColor: DS.background,
      body: const Center(
        child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
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
    return Scaffold(
      backgroundColor: DS.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(DS.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: DS.errorSurface,
                  borderRadius: BorderRadius.circular(DS.radiusLg),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: DS.error,
                  size: 36,
                ),
              ),
              const SizedBox(height: DS.s20),
              const Text(
                'Failed to Load Analytics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DS.textPrimary,
                ),
              ),
              const SizedBox(height: DS.s8),
              const Text(
                'Something went wrong. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DS.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: DS.s24),
              SizedBox(
                height: 48,
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
                      style: TextStyle(
                        fontSize: 15,
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
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.primary,
      body: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -50,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: -30,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          Column(
            children: [
              // Orange hero
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => context.canPop()
                              ? context.pop()
                              : context.go('/home'),
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
                        const Spacer(),
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.28),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: DS.s14),
                        const Text(
                          'My Analytics 📊',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),

              // White card
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
                                  'No Data Yet',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: DS.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Give a test to see your analytics',
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

                        // Placeholder stat cards
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          childAspectRatio: 1.60,
                          crossAxisSpacing: DS.s12,
                          mainAxisSpacing: DS.s12,
                          children: const [
                            _PlaceholderCard(
                              icon: Icons.assignment_turned_in_outlined,
                              label: 'Tests Taken',
                            ),
                            _PlaceholderCard(
                              icon: Icons.show_chart_rounded,
                              label: 'Avg Score',
                            ),
                            _PlaceholderCard(
                              icon: Icons.emoji_events_outlined,
                              label: 'Best Score',
                            ),
                            _PlaceholderCard(
                              icon: Icons.local_fire_department_rounded,
                              label: 'Streak',
                            ),
                          ],
                        ),

                        const SizedBox(height: DS.s28),

                        const Text(
                          'Take your first test to unlock detailed analytics — score trends, subject breakdown, and more.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: DS.textSecondary,
                            fontSize: 13.5,
                            height: 1.6,
                          ),
                        ),

                        const SizedBox(height: DS.s28),

                        // CTA
                        SizedBox(
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
                                  color: DS.primary.withOpacity(0.32),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => context.push('/tests'),
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
                              icon: const Icon(Icons.quiz_rounded, size: 20),
                              label: const Text(
                                'Take a Test Now',
                                style: TextStyle(
                                  fontSize: 15,
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
// PLACEHOLDER CARD (for empty state)
// ─────────────────────────────────────────────
class _PlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s14),
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: DS.surfaceVariant,
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: Icon(icon, color: DS.textHint, size: 20),
          ),
          const SizedBox(width: DS.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 16,
                  width: 40,
                  decoration: BoxDecoration(
                    color: DS.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: DS.s6),
                Text(
                  label,
                  style: const TextStyle(color: DS.textHint, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

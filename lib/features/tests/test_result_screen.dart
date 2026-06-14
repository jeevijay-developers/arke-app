import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'test_engine_screen.dart';

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
// TEST RESULT MODEL
// ─────────────────────────────────────────────
class TestResult {
  final String testId;
  final String attemptId;
  final String title;
  final int score, total, answered;
  final Map<String, dynamic> answers;
  final List<TestQuestion> questions;

  TestResult({
    required this.testId,
    required this.attemptId,
    required this.title,
    required this.score,
    required this.total,
    required this.answered,
    required this.answers,
    required this.questions,
  });
}

// ─────────────────────────────────────────────
// TEST RESULT SCREEN
// ─────────────────────────────────────────────
class TestResultScreen extends StatelessWidget {
  static TestResult? lastResult;
  final String attemptId;
  const TestResultScreen({super.key, required this.attemptId});

  @override
  Widget build(BuildContext context) {
    final r = lastResult;

    if (r == null) {
      return Scaffold(
        backgroundColor: DS.background,
        appBar: _buildAppBar(context, 'Result'),
        body: _NoResultState(),
      );
    }

    final pct = r.total == 0 ? 0 : (r.score * 100 / r.total).round();
    final wrong = r.answered - r.score;
    final skipped = r.total - r.answered;

    // Subject-wise breakdown
    final bySubject = <String, (int correct, int total)>{};
    for (final q in r.questions) {
      final c = r.answers[q.id] == q.correctIndex ? 1 : 0;
      final cur = bySubject[q.subject] ?? (0, 0);
      bySubject[q.subject] = (cur.$1 + c, cur.$2 + 1);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: CustomScrollView(
          slivers: [
            // ── Score hero (SliverAppBar) ──
            SliverToBoxAdapter(
              child: _ScoreHero(
                title: r.title,
                pct: pct,
                score: r.score,
                total: r.total,
                answered: r.answered,
                wrong: wrong,
                skipped: skipped,
                onBack: () => context.go('/tests'),
              ),
            ),

            // ── Body ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                DS.s16,
                DS.s24,
                DS.s16,
                DS.s32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Performance meter ──
                  _PerformanceMeter(pct: pct),
                  const SizedBox(height: DS.s24),

                  // ── Subject-wise ──
                  if (bySubject.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Subject-wise Performance',
                      icon: Icons.insights_rounded,
                      color: DS.indigo,
                    ),
                    const SizedBox(height: DS.s12),
                    ...bySubject.entries.map(
                      (e) => _SubjectBar(
                        subject: e.key,
                        correct: e.value.$1,
                        total: e.value.$2,
                      ),
                    ),
                    const SizedBox(height: DS.s24),
                  ],

                  // ── Questions review ──
                  _SectionHeader(
                    title: 'Questions Review',
                    icon: Icons.quiz_outlined,
                    color: DS.primary,
                  ),
                  const SizedBox(height: DS.s12),
                  ...List.generate(
                    r.questions.length,
                    (i) => _QuestionCard(
                      index: i,
                      question: r.questions[i],
                      picked: r.answers[r.questions[i].id],
                    ),
                  ),

                  const SizedBox(height: DS.s24),

                  // ── Actions ──
                  _PrimaryButton(
                    label: 'Retake Test',
                    icon: Icons.replay_rounded,
                    onTap: () => context.pushReplacement('/test/${r.testId}'),
                  ),
                  const SizedBox(height: DS.s12),
                  _OutlineButton(
                    label: 'Back to Tests',
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.go('/tests'),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext ctx, String title) {
    return AppBar(
      backgroundColor: DS.primary,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => ctx.go('/tests'),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SCORE HERO
// ─────────────────────────────────────────────
class _ScoreHero extends StatelessWidget {
  final String title;
  final int pct, score, total, answered, wrong, skipped;
  final VoidCallback onBack;

  const _ScoreHero({
    required this.title,
    required this.pct,
    required this.score,
    required this.total,
    required this.answered,
    required this.wrong,
    required this.skipped,
    required this.onBack,
  });

  Color get _rankColor {
    if (pct >= 80) return DS.success;
    if (pct >= 60) return DS.primary;
    if (pct >= 40) return DS.warning;
    return DS.error;
  }

  String get _rankLabel {
    if (pct >= 80) return '🏆 Excellent!';
    if (pct >= 60) return '👍 Good Job!';
    if (pct >= 40) return '📚 Keep Practicing';
    return '💪 Don\'t Give Up!';
  }

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
                      const Text(
                        'Result & Analysis',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: DS.s24),

                  // ── Test title ──
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.80),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: DS.s8),

                  // ── Rank label ──
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
                    child: Text(
                      _rankLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(height: DS.s20),

                  // ── Big percentage ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$pct%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 64,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(width: DS.s16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: DS.s8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$score / $total marks',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$answered answered · $skipped skipped',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.70),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: DS.s20),

                  // ── Mini stat row ──
                  Row(
                    children: [
                      _MiniStat(
                        label: 'Correct',
                        value: '$score',
                        icon: Icons.check_circle_rounded,
                        color: DS.success,
                      ),
                      const SizedBox(width: DS.s8),
                      _MiniStat(
                        label: 'Wrong',
                        value: '$wrong',
                        icon: Icons.cancel_rounded,
                        color: DS.error,
                      ),
                      const SizedBox(width: DS.s8),
                      _MiniStat(
                        label: 'Skipped',
                        value: '$skipped',
                        icon: Icons.remove_circle_rounded,
                        color: DS.warning,
                      ),
                      const Spacer(),
                      // Accuracy circle
                      Container(
                        width: 56,
                        height: 56,
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
                              '${answered == 0 ? 0 : (score * 100 / answered).round()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'Accuracy',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.70),
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
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
          top: 40,
          right: 20,
          child: Container(
            width: 60,
            height: 60,
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

class _MiniStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s10, vertical: DS.s8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: DS.s4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.70),
                  fontSize: 10,
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
// PERFORMANCE METER
// ─────────────────────────────────────────────
class _PerformanceMeter extends StatelessWidget {
  final int pct;
  const _PerformanceMeter({required this.pct});

  Color get _barColor {
    if (pct >= 80) return DS.success;
    if (pct >= 60) return DS.primary;
    if (pct >= 40) return DS.warning;
    return DS.error;
  }

  String get _grade {
    if (pct >= 90) return 'A+';
    if (pct >= 80) return 'A';
    if (pct >= 70) return 'B+';
    if (pct >= 60) return 'B';
    if (pct >= 50) return 'C';
    if (pct >= 40) return 'D';
    return 'F';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s20),
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
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _barColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: DS.s8),
              const Text(
                'Overall Performance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: DS.textPrimary,
                ),
              ),
              const Spacer(),
              // Grade badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _barColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  border: Border.all(
                    color: _barColor.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    _grade,
                    style: TextStyle(
                      color: _barColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: DS.s16),

          // Segmented progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: [
                Container(height: 14, color: DS.border),
                FractionallySizedBox(
                  widthFactor: pct / 100,
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_barColor.withOpacity(0.70), _barColor],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: DS.s10),

          // Scale labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ScaleLabel(label: '0%', color: DS.error),
              _ScaleLabel(label: '40%', color: DS.warning),
              _ScaleLabel(label: '60%', color: DS.primary),
              _ScaleLabel(label: '80%', color: DS.success),
              _ScaleLabel(label: '100%', color: DS.success),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScaleLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _ScaleLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
  );
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
          child: Icon(icon, size: 16, color: color),
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
// SUBJECT BAR
// ─────────────────────────────────────────────
class _SubjectBar extends StatelessWidget {
  final String subject;
  final int correct, total;

  const _SubjectBar({
    required this.subject,
    required this.correct,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final val = total == 0 ? 0.0 : correct / total;
    final pctS = (val * 100).round();
    final Color barColor;
    final Color barSurface;

    if (pctS >= 80) {
      barColor = DS.success;
      barSurface = DS.successSurface;
    } else if (pctS >= 60) {
      barColor = DS.primary;
      barSurface = DS.primaryLight;
    } else if (pctS >= 40) {
      barColor = DS.warning;
      barSurface = DS.warningSurface;
    } else {
      barColor = DS.error;
      barSurface = DS.errorSurface;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: DS.s10),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Subject icon
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: barSurface,
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                child: Icon(Icons.book_outlined, size: 16, color: barColor),
              ),
              const SizedBox(width: DS.s10),
              Expanded(
                child: Text(
                  subject,
                  style: const TextStyle(
                    color: DS.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '$correct/$total',
                style: const TextStyle(color: DS.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(width: DS.s8),
              // Percentage badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s8,
                  vertical: DS.s4,
                ),
                decoration: BoxDecoration(
                  color: barColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: barColor.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Text(
                  '$pctS%',
                  style: TextStyle(
                    color: barColor,
                    fontSize: 12,
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
              value: val,
              minHeight: 8,
              backgroundColor: DS.border,
              color: barColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// QUESTION CARD
// ─────────────────────────────────────────────
class _QuestionCard extends StatefulWidget {
  final int index;
  final TestQuestion question;
  final dynamic picked; // int? for MCQ, String for fill-in, null = skipped

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.picked,
  });

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  bool _expanded = false;

  bool get _skipped => widget.picked == null;
  bool get _correct {
    if (_skipped) return false;
    final q = widget.question;
    if (q.isIntegerType) {
      return widget.picked.toString().trim() == q.correctAnswerText.trim();
    }
    return widget.picked == q.correctIndex;
  }

  Color get _statusColor {
    if (_skipped) return DS.warning;
    if (_correct) return DS.success;
    return DS.error;
  }

  IconData get _statusIcon {
    if (_skipped) return Icons.remove_circle_rounded;
    if (_correct) return Icons.check_circle_rounded;
    return Icons.cancel_rounded;
  }

  String get _statusLabel {
    if (_skipped) return 'Skipped';
    if (_correct) return 'Correct';
    return 'Wrong';
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final i = widget.index;

    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s10),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _expanded = !_expanded);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(DS.s14),
          decoration: BoxDecoration(
            color: DS.surface,
            borderRadius: BorderRadius.circular(DS.radiusMd),
            border: Border.all(
              color: _expanded
                  ? _statusColor.withOpacity(0.40)
                  : _statusColor.withOpacity(0.20),
              width: _expanded ? 1.6 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _expanded
                    ? _statusColor.withOpacity(0.08)
                    : Colors.black.withOpacity(0.03),
                blurRadius: _expanded ? 10 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──
              Row(
                children: [
                  // Status icon tile
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                    ),
                    child: Icon(_statusIcon, size: 16, color: _statusColor),
                  ),
                  const SizedBox(width: DS.s8),

                  // Q number + status
                  Text(
                    'Q${i + 1}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: DS.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: DS.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s8,
                      vertical: DS.s2,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Subject chip
                  if (q.subject.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DS.s6,
                        vertical: DS.s2,
                      ),
                      decoration: BoxDecoration(
                        color: DS.primaryLight,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        q.subject,
                        style: const TextStyle(
                          color: DS.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: DS.s8),

                  // Expand chevron
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: DS.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: DS.s10),

              // ── Question text ──
              MathText(
                q.text,
                style: const TextStyle(
                  color: DS.textPrimary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
                maxLines: _expanded ? null : 2,
              ),

              // ── Question images ──
              if (_expanded && q.imageUrls.isNotEmpty) ...[
                const SizedBox(height: DS.s8),
                ...q.imageUrls.map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(bottom: DS.s6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Container(
                          height: 120,
                          color: DS.surfaceVariant,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: DS.primary,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: DS.surfaceVariant,
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                          ),
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: DS.textSecondary, size: 28),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              // ── Options (expanded only) ──
              if (_expanded) ...[
                const SizedBox(height: DS.s12),
                if (q.isIntegerType) ...[
                  // Fill-in review: show typed answer vs correct answer
                  _FillInReviewRow(
                    label: 'Your answer',
                    value: _skipped ? '—' : widget.picked.toString(),
                    color: _skipped ? DS.warning : (_correct ? DS.success : DS.error),
                  ),
                  const SizedBox(height: DS.s6),
                  _FillInReviewRow(
                    label: 'Correct answer',
                    value: q.correctAnswerText,
                    color: DS.success,
                  ),
                ] else
                ...List.generate(q.options.length, (oi) {
                  final isCorrect = oi == q.correctIndex;
                  final isWrong = oi == widget.picked && !isCorrect;
                  final isPicked = oi == widget.picked;

                  Color? bg;
                  Color border = DS.border;
                  Color textC = DS.textPrimary;
                  Color labelC = DS.textSecondary;

                  if (isCorrect) {
                    bg = DS.successSurface;
                    border = DS.success;
                    textC = DS.success;
                    labelC = DS.success;
                  } else if (isWrong) {
                    bg = DS.errorSurface;
                    border = DS.error;
                    textC = DS.error;
                    labelC = DS.error;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: DS.s6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s12,
                      vertical: DS.s10,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                      border: Border.all(color: border, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        // Option letter
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: isCorrect
                                ? DS.success.withOpacity(0.15)
                                : isWrong
                                ? DS.error.withOpacity(0.15)
                                : DS.surfaceVariant,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + oi),
                              style: TextStyle(
                                color: labelC,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: DS.s10),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (q.options[oi].text.isNotEmpty)
                                MathText(
                                  q.options[oi].text,
                                  style: TextStyle(
                                    color: textC,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              if (q.options[oi].imageUrl != null) ...[
                                if (q.options[oi].text.isNotEmpty)
                                  const SizedBox(height: DS.s6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(DS.radiusSm),
                                  child: CachedNetworkImage(
                                    imageUrl: q.options[oi].imageUrl!,
                                    fit: BoxFit.contain,
                                    placeholder: (_, _) => Container(
                                      height: 60,
                                      color: DS.surfaceVariant,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: DS.primary,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, _, _) => const Icon(
                                      Icons.broken_image_outlined,
                                      color: DS.textSecondary,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: DS.s8),

                        // Status icon
                        if (isCorrect)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: DS.success,
                            size: 16,
                          )
                        else if (isWrong)
                          const Icon(
                            Icons.cancel_rounded,
                            color: DS.error,
                            size: 16,
                          ),
                      ],
                    ),
                  );
                }),

                // ── Explanation ──
                if (q.explanation != null && q.explanation!.isNotEmpty) ...[
                  const SizedBox(height: DS.s8),
                  Container(
                    padding: const EdgeInsets.all(DS.s12),
                    decoration: BoxDecoration(
                      color: DS.indigoLight,
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                      border: Border.all(
                        color: DS.indigo.withOpacity(0.20),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: DS.indigo.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                          ),
                          child: const Icon(
                            Icons.lightbulb_rounded,
                            size: 14,
                            color: DS.indigo,
                          ),
                        ),
                        const SizedBox(width: DS.s8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Explanation',
                                style: TextStyle(
                                  color: DS.indigo,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: DS.s4),
                              MathText(
                                q.explanation!,
                                style: const TextStyle(
                                  color: DS.textPrimary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FILL-IN REVIEW ROW
// ─────────────────────────────────────────────
class _FillInReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _FillInReviewRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s12, vertical: DS.s10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 1.2),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: DS.s8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PRIMARY BUTTON
// ─────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
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
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
          ),
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// OUTLINE BUTTON
// ─────────────────────────────────────────────
class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: DS.textPrimary,
          side: const BorderSide(color: DS.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radiusMd),
          ),
          backgroundColor: DS.surface,
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NO RESULT STATE
// ─────────────────────────────────────────────
class _NoResultState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
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
                Icons.assignment_late_outlined,
                color: DS.error,
                size: 36,
              ),
            ),
            const SizedBox(height: DS.s20),
            const Text(
              'No Result Available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s8),
            const Text(
              'Something went wrong loading your test result. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DS.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTE: MathText is imported from test_engine_screen.dart
// It renders LaTeX/math expressions inline.
// Ensure it accepts maxLines parameter or wrap in a widget
// that handles truncation at the parent level.
// ─────────────────────────────────────────────

// Helper extension for question card access
extension on _QuestionCardState {
  TestQuestion get q => widget.question;
}

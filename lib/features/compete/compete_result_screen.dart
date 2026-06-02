import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'compete_models.dart';
import 'compete_question.dart';
import 'math_html_widget.dart';

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
  static const double s3 = 3;
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
// COMPETE RESULT SCREEN
// ─────────────────────────────────────────────
class CompeteResultScreen extends StatefulWidget {
  final CompeteMatch match;
  final List<CompeteAnswer> myAnswers;
  final List<CompeteAnswer> oppAnswers;
  final List<CompeteQuestion> questions;
  final String userId;
  final VoidCallback onPlayAgain;
  final VoidCallback onLobby;

  const CompeteResultScreen({
    super.key,
    required this.match,
    required this.myAnswers,
    this.oppAnswers = const [],
    required this.questions,
    required this.userId,
    required this.onPlayAgain,
    required this.onLobby,
  });

  @override
  State<CompeteResultScreen> createState() => _CompeteResultScreenState();
}

class _CompeteResultScreenState extends State<CompeteResultScreen> {
  int _tab = 0;

  // ── Derived helpers ──────────────────────────────────────────────────────
  bool get _imP1 => widget.match.player1Id == widget.userId;
  String get _myName => _imP1
      ? (widget.match.player1Name ?? 'You')
      : (widget.match.player2Name ?? 'You');
  String get _oppName {
    final n = _imP1 ? widget.match.player2Name : widget.match.player1Name;
    return widget.match.isBot ? 'AI Opponent' : (n ?? 'Opponent');
  }

  int get _myScore =>
      _imP1 ? widget.match.player1Score : widget.match.player2Score;
  int get _oppScore =>
      _imP1 ? widget.match.player2Score : widget.match.player1Score;
  bool get _isWin => widget.match.winnerId == widget.userId;
  bool get _isDraw =>
      widget.match.status == 'finished' && widget.match.winnerId == null;
  bool get _isLoss => !_isWin && !_isDraw;

  int get _correct => widget.myAnswers.where((a) => a.isCorrect).length;
  int get _accuracy => widget.questions.isEmpty
      ? 0
      : ((_correct / widget.questions.length) * 100).round();
  double get _avgTime {
    if (widget.myAnswers.isEmpty) return 0;
    return widget.myAnswers.map((a) => a.timeTakenMs).reduce((a, b) => a + b) /
        widget.myAnswers.length /
        1000;
  }

  double get _fastest {
    final c = widget.myAnswers.where((a) => a.isCorrect);
    if (c.isEmpty) return 0;
    return c.map((a) => a.timeTakenMs).reduce((a, b) => a < b ? a : b) / 1000;
  }

  int? get _ratingBefore => _imP1
      ? widget.match.player1RatingBefore
      : widget.match.player2RatingBefore;
  int? get _ratingAfter =>
      _imP1 ? widget.match.player1RatingAfter : widget.match.player2RatingAfter;
  int? get _eloDelta {
    if (_ratingBefore == null || _ratingAfter == null) return null;
    return _ratingAfter! - _ratingBefore!;
  }

  Color get _resultColor => _isDraw
      ? DS.warning
      : _isWin
      ? DS.success
      : DS.error;
  Color get _resultSurface => _isDraw
      ? DS.warningSurface
      : _isWin
      ? DS.successSurface
      : DS.errorSurface;

  String get _resultLabel => _isDraw
      ? 'Draw!'
      : _isWin
      ? 'Victory! 🏆'
      : 'Defeated';
  String get _resultEmoji => _isDraw
      ? '🤝'
      : _isWin
      ? '🥇'
      : '💪';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: Column(
          children: [
            // ── Result hero header ──
            _ResultHeader(
              resultLabel: _resultLabel,
              resultEmoji: _resultEmoji,
              resultColor: _resultColor,
              resultSurface: _resultSurface,
              isWin: _isWin,
              isDraw: _isDraw,
            ),

            // ── Scrollable content ──
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Score + stats + ELO + tabs
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        DS.s16,
                        DS.s20,
                        DS.s16,
                        0,
                      ),
                      child: Column(
                        children: [
                          // Score cards
                          _ScoreRow(
                            myName: _myName,
                            oppName: _oppName,
                            myScore: _myScore,
                            oppScore: _oppScore,
                            isWin: _isWin,
                            isLoss: _isLoss,
                          ),
                          const SizedBox(height: DS.s12),

                          // Stats strip
                          _StatsStrip(
                            accuracy: _accuracy,
                            correct: _correct,
                            total: widget.questions.length,
                            avgTime: _avgTime,
                            fastest: _fastest,
                          ),
                          const SizedBox(height: DS.s12),

                          // ELO card
                          if (!widget.match.isBot && _eloDelta != null)
                            _EloCard(
                              before: _ratingBefore!,
                              after: _ratingAfter!,
                              delta: _eloDelta!,
                            )
                          else if (!widget.match.isBot && _ratingBefore != null)
                            _EloEstimateCard(
                              before: _ratingBefore!,
                              isWin: _isWin,
                              isDraw: _isDraw,
                              oppRating: _imP1
                                  ? widget.match.player2RatingBefore
                                  : widget.match.player1RatingBefore,
                            ),

                          const SizedBox(height: DS.s16),

                          // Tab bar
                          _DSTabBar(
                            tab: _tab,
                            label1: 'Summary',
                            label2: 'Review (${widget.questions.length})',
                            onTab: (i) => setState(() => _tab = i),
                          ),
                          const SizedBox(height: DS.s4),
                        ],
                      ),
                    ),
                  ),

                  // Tab content
                  if (_tab == 0)
                    _SummarySliver(
                      questions: widget.questions,
                      myAnswers: widget.myAnswers,
                      oppAnswers: widget.oppAnswers,
                      oppName: _oppName,
                    )
                  else
                    _ReviewSliver(
                      questions: widget.questions,
                      myAnswers: widget.myAnswers,
                      oppAnswers: widget.oppAnswers,
                      oppName: _oppName,
                    ),
                ],
              ),
            ),

            // ── Action buttons ──
            _ActionBar(
              onPlayAgain: widget.onPlayAgain,
              onLobby: widget.onLobby,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RESULT HEADER
// ─────────────────────────────────────────────
class _ResultHeader extends StatelessWidget {
  final String resultLabel, resultEmoji;
  final Color resultColor, resultSurface;
  final bool isWin, isDraw;

  const _ResultHeader({
    required this.resultLabel,
    required this.resultEmoji,
    required this.resultColor,
    required this.resultSurface,
    required this.isWin,
    required this.isDraw,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFFF8C38), DS.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(DS.radiusXl),
              bottomRight: Radius.circular(DS.radiusXl),
            ),
            boxShadow: const [
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
              padding: const EdgeInsets.fromLTRB(
                DS.s20,
                DS.s12,
                DS.s20,
                DS.s28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: icon + title
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.28),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            resultEmoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: DS.s14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Compete Result',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            resultLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: DS.s20),

                  // Result status pill
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
                        Icon(
                          isWin
                              ? Icons.emoji_events_rounded
                              : isDraw
                              ? Icons.handshake_outlined
                              : Icons.sports_kabaddi_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: DS.s6),
                        Text(
                          isWin
                              ? '⚔️ Battle won — great job!'
                              : isDraw
                              ? '🤝 Evenly matched!'
                              : '💪 Keep competing!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          top: 20,
          right: 20,
          child: Container(
            width: 50,
            height: 50,
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
// SCORE ROW
// ─────────────────────────────────────────────
class _ScoreRow extends StatelessWidget {
  final String myName, oppName;
  final int myScore, oppScore;
  final bool isWin, isLoss;

  const _ScoreRow({
    required this.myName,
    required this.oppName,
    required this.myScore,
    required this.oppScore,
    required this.isWin,
    required this.isLoss,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _ScoreCard(
          name: myName,
          score: myScore,
          isHighlight: isWin,
          highlightColor: DS.success,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: DS.s8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: DS.primaryLight,
            borderRadius: BorderRadius.circular(DS.radiusSm),
          ),
          child: const Center(
            child: Text(
              'VS',
              style: TextStyle(
                color: DS.primary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
      Expanded(
        child: _ScoreCard(
          name: oppName,
          score: oppScore,
          isHighlight: isLoss,
          highlightColor: DS.error,
        ),
      ),
    ],
  );
}

class _ScoreCard extends StatelessWidget {
  final String name;
  final int score;
  final bool isHighlight;
  final Color highlightColor;

  const _ScoreCard({
    required this.name,
    required this.score,
    required this.isHighlight,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: DS.s16),
    decoration: BoxDecoration(
      color: isHighlight ? highlightColor.withOpacity(0.06) : DS.surface,
      borderRadius: BorderRadius.circular(DS.radiusMd),
      border: Border.all(
        color: isHighlight ? highlightColor.withOpacity(0.35) : DS.border,
        width: isHighlight ? 1.8 : 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        Text(
          name.length > 12 ? '${name.substring(0, 12)}…' : name,
          style: const TextStyle(color: DS.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: DS.s6),
        Text(
          '$score',
          style: TextStyle(
            color: isHighlight ? highlightColor : DS.textPrimary,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        Text('pts', style: const TextStyle(color: DS.textHint, fontSize: 11)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// STATS STRIP
// ─────────────────────────────────────────────
class _StatsStrip extends StatelessWidget {
  final int accuracy, correct, total;
  final double avgTime, fastest;

  const _StatsStrip({
    required this.accuracy,
    required this.correct,
    required this.total,
    required this.avgTime,
    required this.fastest,
  });

  @override
  Widget build(BuildContext context) {
    final stats = [
      _MiniStatData(
        Icons.track_changes_rounded,
        'Accuracy',
        '$accuracy%',
        DS.primary,
      ),
      _MiniStatData(
        Icons.check_circle_outline_rounded,
        'Correct',
        '$correct/$total',
        DS.success,
      ),
      _MiniStatData(
        Icons.bolt_rounded,
        'Avg Time',
        '${avgTime.toStringAsFixed(1)}s',
        DS.warning,
      ),
      _MiniStatData(
        Icons.local_fire_department_rounded,
        'Fastest',
        '${fastest.toStringAsFixed(1)}s',
        DS.error,
      ),
    ];
    return Row(
      children: stats
          .asMap()
          .entries
          .expand(
            (e) => [
              if (e.key > 0) const SizedBox(width: DS.s8),
              Expanded(child: _MiniStatCard(data: e.value)),
            ],
          )
          .toList(),
    );
  }
}

class _MiniStatData {
  final IconData icon;
  final String label, value;
  final Color color;
  const _MiniStatData(this.icon, this.label, this.value, this.color);
}

class _MiniStatCard extends StatelessWidget {
  final _MiniStatData data;
  const _MiniStatCard({required this.data});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: DS.s10),
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
    child: Column(
      children: [
        Icon(data.icon, color: data.color, size: 15),
        const SizedBox(height: DS.s4),
        Text(
          data.value,
          style: const TextStyle(
            color: DS.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: DS.s2),
        Text(
          data.label,
          style: const TextStyle(
            color: DS.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// ELO CARD (actual delta)
// ─────────────────────────────────────────────
class _EloCard extends StatelessWidget {
  final int before, after, delta;
  const _EloCard({
    required this.before,
    required this.after,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    final positive = delta >= 0;
    final color = positive ? DS.success : DS.error;
    final surface = positive ? DS.successSurface : DS.errorSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: color.withOpacity(0.25), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: Icon(
              positive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: DS.s12),
          Text(
            'Rating',
            style: const TextStyle(color: DS.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: DS.s8),
          Text(
            '$before',
            style: const TextStyle(
              color: DS.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DS.s8),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: DS.textHint,
              size: 14,
            ),
          ),
          Text(
            '$after',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: DS.s8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s8,
              vertical: DS.s3,
            ),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              delta == 0
                  ? '±0'
                  : delta > 0
                  ? '+$delta'
                  : '$delta',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ELO ESTIMATE CARD (when actual not available)
// ─────────────────────────────────────────────
class _EloEstimateCard extends StatelessWidget {
  final int before;
  final bool isWin, isDraw;
  final int? oppRating;

  const _EloEstimateCard({
    required this.before,
    required this.isWin,
    required this.isDraw,
    this.oppRating,
  });

  @override
  Widget build(BuildContext context) {
    final opp = oppRating ?? 1000;
    final delta = calcEloDelta(
      myRating: before,
      opponentRating: opp,
      won: isWin,
      draw: isDraw,
    );
    final after = before + delta;
    return _EloCard(before: before, after: after, delta: delta);
  }
}

// ─────────────────────────────────────────────
// DS TAB BAR
// ─────────────────────────────────────────────
class _DSTabBar extends StatelessWidget {
  final int tab;
  final String label1, label2;
  final void Function(int) onTab;

  const _DSTabBar({
    required this.tab,
    required this.label1,
    required this.label2,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(DS.s4),
    decoration: BoxDecoration(
      color: DS.surfaceVariant,
      borderRadius: BorderRadius.circular(DS.radiusSm),
      border: Border.all(color: DS.border, width: 1.2),
    ),
    child: Row(
      children: [
        Expanded(
          child: _TabBtn(
            label: label1,
            active: tab == 0,
            onTap: () {
              HapticFeedback.selectionClick();
              onTab(0);
            },
          ),
        ),
        const SizedBox(width: DS.s4),
        Expanded(
          child: _TabBtn(
            label: label2,
            active: tab == 1,
            onTap: () {
              HapticFeedback.selectionClick();
              onTab(1);
            },
          ),
        ),
      ],
    ),
  );
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabBtn({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(vertical: DS.s10),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(
                colors: [Color(0xFFFF8C38), DS.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: active ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(DS.radiusSm - 2),
        boxShadow: active
            ? [
                BoxShadow(
                  color: DS.primary.withOpacity(0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: active ? Colors.white : DS.textSecondary,
          fontSize: 13,
          fontWeight: active ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// SUMMARY SLIVER
// ─────────────────────────────────────────────
class _SummarySliver extends StatelessWidget {
  final List<CompeteQuestion> questions;
  final List<CompeteAnswer> myAnswers, oppAnswers;
  final String oppName;

  const _SummarySliver({
    required this.questions,
    required this.myAnswers,
    required this.oppAnswers,
    required this.oppName,
  });

  @override
  Widget build(BuildContext context) {
    final hasOpp = oppAnswers.isNotEmpty;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s8),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Card wrapper
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
                // Header
                Row(
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
                    const Text(
                      'Question Breakdown',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DS.textPrimary,
                      ),
                    ),
                  ],
                ),

                if (hasOpp) ...[
                  const SizedBox(height: DS.s12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'You',
                          style: const TextStyle(
                            color: DS.textSecondary,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: DS.s6),
                      Expanded(
                        child: Text(
                          oppName.length > 10
                              ? '${oppName.substring(0, 10)}…'
                              : oppName,
                          style: const TextStyle(
                            color: DS.textHint,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: DS.s12),

                // Pip grid
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(questions.length, (i) {
                    final myAns = myAnswers
                        .where((a) => a.questionIndex == i)
                        .firstOrNull;
                    final myOk = myAns?.isCorrect ?? false;
                    final mySkip = myAns == null;
                    final oppAns = oppAnswers
                        .where((a) => a.questionIndex == i)
                        .firstOrNull;
                    final oppOk = oppAns?.isCorrect ?? false;
                    final oppSkip = oppAns == null;

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: DS.s3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // My pip
                            Container(
                              height: 32,
                              decoration: BoxDecoration(
                                color: mySkip
                                    ? DS.border
                                    : myOk
                                    ? DS.success
                                    : DS.error,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(DS.s4),
                                ),
                              ),
                            ),
                            // Opp pip
                            if (hasOpp) ...[
                              const SizedBox(height: DS.s2),
                              Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  color: oppSkip
                                      ? DS.surfaceVariant
                                      : oppOk
                                      ? DS.success.withOpacity(0.40)
                                      : DS.error.withOpacity(0.40),
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(DS.s4),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: DS.s4),
                            Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: DS.textHint,
                                fontSize: 8,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: DS.s14),
                Divider(color: DS.border, height: 1),
                const SizedBox(height: DS.s12),

                // Legend
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: DS.s14,
                  runSpacing: DS.s6,
                  children: [
                    _LegendDot(color: DS.success, label: 'Correct'),
                    _LegendDot(color: DS.error, label: 'Wrong'),
                    _LegendDot(color: DS.border, label: 'Skipped'),
                    if (hasOpp)
                      _LegendDot(
                        color: DS.success.withOpacity(0.40),
                        label: 'Opp Correct',
                      ),
                    if (hasOpp)
                      _LegendDot(
                        color: DS.error.withOpacity(0.40),
                        label: 'Opp Wrong',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: DS.s4),
      Text(
        label,
        style: const TextStyle(color: DS.textSecondary, fontSize: 11),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
// REVIEW SLIVER
// ─────────────────────────────────────────────
class _ReviewSliver extends StatelessWidget {
  final List<CompeteQuestion> questions;
  final List<CompeteAnswer> myAnswers, oppAnswers;
  final String oppName;

  const _ReviewSliver({
    required this.questions,
    required this.myAnswers,
    required this.oppAnswers,
    required this.oppName,
  });

  @override
  Widget build(BuildContext context) {
    final shortOpp = oppName.length > 8
        ? '${oppName.substring(0, 8)}…'
        : oppName;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s14, DS.s16, DS.s8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((_, qi) {
          if (qi >= questions.length) return null;
          final q = questions[qi];
          final myAns = myAnswers
              .where((a) => a.questionIndex == qi)
              .firstOrNull;
          final oppAns = oppAnswers
              .where((a) => a.questionIndex == qi)
              .firstOrNull;
          final myOk = myAns?.isCorrect ?? false;
          final mySkip = myAns == null;
          final timeSec = myAns != null
              ? (myAns.timeTakenMs / 1000).toStringAsFixed(1)
              : null;
          final pts = myAns?.points ?? 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: DS.s14),
            child: Container(
              padding: const EdgeInsets.all(DS.s14),
              decoration: BoxDecoration(
                color: DS.surface,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(
                  color: mySkip
                      ? DS.border
                      : myOk
                      ? DS.success.withOpacity(0.30)
                      : DS.error.withOpacity(0.30),
                  width: 1.2,
                ),
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
                  // Header
                  Row(
                    children: [
                      // Q number
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DS.s8,
                          vertical: DS.s4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8C38), DS.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                        ),
                        child: Text(
                          'Q${qi + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // My badge
                      _ReviewBadge(
                        label: mySkip
                            ? 'You: Skip'
                            : 'You: ${timeSec}s · ${pts}pt',
                        isCorrect: myOk,
                        isSkipped: mySkip,
                      ),
                      if (oppAns != null) ...[
                        const SizedBox(width: DS.s6),
                        _ReviewBadge(
                          label: '$shortOpp: ${oppAns.isCorrect ? '✓' : '✗'}',
                          isCorrect: oppAns.isCorrect,
                          isSkipped: false,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: DS.s12),
                  Divider(color: DS.border, height: 1),
                  const SizedBox(height: DS.s12),

                  // Question text
                  MathHtmlWidget(
                    q.questionText,
                    textStyle: const TextStyle(
                      color: DS.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: DS.s12),

                  // Options
                  ...List.generate(q.options.length, (oi) {
                    final isCorrect = oi == q.correct;
                    final isMyPick = myAns?.selectedIndex == oi;
                    final isOppPick = oppAns?.selectedIndex == oi;
                    final isWrong = isMyPick && !isCorrect;
                    final isOppWrong = isOppPick && !isCorrect;

                    Color bg = Colors.transparent;
                    Color border = DS.border;
                    Color labelC = DS.textSecondary;

                    if (isCorrect) {
                      bg = DS.successSurface;
                      border = DS.success.withOpacity(0.40);
                      labelC = DS.success;
                    } else if (isWrong || isOppWrong) {
                      bg = DS.errorSurface;
                      border = DS.error.withOpacity(0.35);
                      labelC = DS.error;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: DS.s8),
                      child: Container(
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
                            // Letter badge
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? DS.success.withOpacity(0.12)
                                    : isWrong || isOppWrong
                                    ? DS.error.withOpacity(0.12)
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
                              child: MathHtmlWidget(
                                q.options[oi],
                                textStyle: TextStyle(
                                  color: isCorrect
                                      ? DS.success
                                      : isWrong
                                      ? DS.error
                                      : DS.textPrimary,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            // Status icons
                            if (isCorrect) ...[
                              const Icon(
                                Icons.check_circle_rounded,
                                color: DS.success,
                                size: 16,
                              ),
                              if (isMyPick)
                                Padding(
                                  padding: const EdgeInsets.only(left: DS.s4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DS.s6,
                                      vertical: DS.s2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: DS.successSurface,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(
                                        color: DS.success,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                            if (isWrong)
                              const Icon(
                                Icons.cancel_rounded,
                                color: DS.error,
                                size: 16,
                              ),
                            // Opp marker
                            if (isOppPick) ...[
                              const SizedBox(width: DS.s4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: DS.s6,
                                  vertical: DS.s2,
                                ),
                                decoration: BoxDecoration(
                                  color: (isOppWrong
                                      ? DS.errorSurface
                                      : DS.successSurface),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: (isOppWrong ? DS.error : DS.success)
                                        .withOpacity(0.30),
                                  ),
                                ),
                                child: Text(
                                  shortOpp,
                                  style: TextStyle(
                                    color: isOppWrong ? DS.error : DS.success,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  // Explanation
                  if ((q.explanation ?? '').isNotEmpty) ...[
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
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: DS.indigo.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(DS.radiusSm),
                            ),
                            child: const Icon(
                              Icons.lightbulb_rounded,
                              color: DS.indigo,
                              size: 13,
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
                                  ),
                                ),
                                const SizedBox(height: DS.s4),
                                MathHtmlWidget(
                                  q.explanation!,
                                  textStyle: const TextStyle(
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
              ),
            ),
          );
        }, childCount: questions.length),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REVIEW BADGE
// ─────────────────────────────────────────────
class _ReviewBadge extends StatelessWidget {
  final String label;
  final bool isCorrect, isSkipped;

  const _ReviewBadge({
    required this.label,
    required this.isCorrect,
    required this.isSkipped,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSkipped
        ? DS.textSecondary
        : isCorrect
        ? DS.success
        : DS.error;
    final surface = isSkipped
        ? DS.surfaceVariant
        : isCorrect
        ? DS.successSurface
        : DS.errorSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: color.withOpacity(0.30), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACTION BAR
// ─────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final VoidCallback onPlayAgain, onLobby;
  const _ActionBar({
    required this.onPlayAgain,
    required this.onLobby,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DS.s16,
        DS.s10,
        DS.s16,
        DS.s10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(top: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Play Again — full width gradient
          SizedBox(
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
                onPressed: onPlayAgain,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Play Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DS.s10),

          // Lobby
          _OutlineActionButton(
            icon: Icons.home_outlined,
            label: 'Lobby',
            onTap: onLobby,
          ),
        ],
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OutlineActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(
      label,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
    ),
    style: OutlinedButton.styleFrom(
      foregroundColor: DS.textPrimary,
      side: const BorderSide(color: DS.border, width: 1.2),
      padding: const EdgeInsets.symmetric(vertical: DS.s12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusMd),
      ),
    ),
  );
}

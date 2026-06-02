import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/colors.dart';
import 'compete_question.dart';

class BattleResultScreen extends StatefulWidget {
  final int playerScore;
  final int opponentScore;
  final String opponentName;
  final int totalQuestions;
  final bool isBot;
  final List<CompeteQuestion> questions;
  final List<Map<String, dynamic>> questionLog;
  final double avgTimeSecs;
  final double fastestTimeSecs;

  const BattleResultScreen({
    super.key,
    required this.playerScore,
    required this.opponentScore,
    required this.opponentName,
    required this.totalQuestions,
    required this.isBot,
    required this.questions,
    required this.questionLog,
    required this.avgTimeSecs,
    required this.fastestTimeSecs,
  });

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen> {
  static const _bg     = Color(0xFF0F172A);
  static const _card   = Color(0xFF1E293B);
  static const _border = Color(0xFF334155);
  static const _muted  = Color(0xFF94A3B8);

  int _tab = 0; // 0 = Summary, 1 = Review

  bool get _won  => widget.playerScore > widget.opponentScore;
  bool get _draw => widget.playerScore == widget.opponentScore;

  int get _correctCount => widget.questionLog
      .where((e) {
        final pa = e['playerAnswer'] as int?;
        return pa != null && pa == (e['correctIndex'] as int);
      })
      .length;

  int get _accuracy =>
      widget.totalQuestions > 0 ? ((_correctCount / widget.totalQuestions) * 100).round() : 0;

  @override
  Widget build(BuildContext context) {
    final resultColor = _draw
        ? const Color(0xFFF59E0B)
        : _won
            ? AppColors.teal
            : AppColors.red;

    final resultLabel = _draw ? 'Draw!' : _won ? 'Victory!' : 'Defeated';

    final ratingDelta = _won ? 16 : _draw ? 0 : -16;
    final newRating   = 1000 + ratingDelta;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(children: [
                  // Crown icon
                  Icon(
                    Icons.workspace_premium_rounded,
                    color: resultColor,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(resultLabel,
                    style: TextStyle(
                      color: resultColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    )),
                  const SizedBox(height: 20),

                  // ── Score cards ─────────────────────────────────────────
                  Row(children: [
                    // Player card
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Column(children: [
                          Text('You',
                            style: const TextStyle(color: _muted, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text('${widget.playerScore}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            )),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Opponent card (highlighted if winner)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: !_won ? AppColors.red : _border,
                            width: !_won ? 2 : 1,
                          ),
                        ),
                        child: Column(children: [
                          Text(
                            widget.opponentName.length > 12
                                ? '${widget.opponentName.substring(0, 12)}…'
                                : widget.opponentName,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text('${widget.opponentScore}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                            )),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Stat chips ──────────────────────────────────────────
                  Row(children: [
                    _StatChip(
                      icon: Icons.track_changes_rounded,
                      label: 'ACCURACY',
                      value: '$_accuracy%',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.check_rounded,
                      label: 'CORRECT',
                      value: '$_correctCount/${widget.totalQuestions}',
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.bolt_rounded,
                      label: 'AVG TIME',
                      value: '${widget.avgTimeSecs.toStringAsFixed(1)}s',
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      icon: Icons.local_fire_department_rounded,
                      label: 'FASTEST',
                      value: '${widget.fastestTimeSecs.toStringAsFixed(1)}s',
                      color: AppColors.red,
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // ── Rating change ───────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          ratingDelta >= 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          color: ratingDelta >= 0 ? AppColors.teal : AppColors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Text('Rating  ',
                          style: TextStyle(color: _muted, fontSize: 13)),
                        const Text('1000',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          )),
                        const Text('  →  ',
                          style: TextStyle(color: _muted, fontSize: 13)),
                        Text('$newRating',
                          style: TextStyle(
                            color: ratingDelta >= 0 ? AppColors.teal : AppColors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          )),
                        const SizedBox(width: 6),
                        Text(
                          ratingDelta == 0
                              ? '(0)'
                              : ratingDelta > 0
                                  ? '(+$ratingDelta)'
                                  : '($ratingDelta)',
                          style: TextStyle(
                            color: ratingDelta >= 0 ? AppColors.teal : AppColors.red,
                            fontSize: 12,
                          )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Tab selector ────────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Row(children: [
                      _TabBtn(
                        label: 'Summary',
                        active: _tab == 0,
                        onTap: () => setState(() => _tab = 0),
                      ),
                      _TabBtn(
                        label: 'Review (${widget.totalQuestions})',
                        active: _tab == 1,
                        onTap: () => setState(() => _tab = 1),
                      ),
                    ]),
                  ),
                ]),
              ),

              // ── Tab content ──────────────────────────────────────────────
              Expanded(
                child: _tab == 0
                    ? _SummaryTab(
                        questions:   widget.questions,
                        questionLog: widget.questionLog,
                        playerName:  'You',
                        opponentName: widget.opponentName,
                      )
                    : _ReviewTab(
                        questions:   widget.questions,
                        questionLog: widget.questionLog,
                      ),
              ),

              // ── Action buttons ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Play Again',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Pop back to lobby (2 screens: result + game)
                        int count = 0;
                        Navigator.of(context).popUntil((_) => count++ >= 2);
                      },
                      icon: const Icon(Icons.home_outlined, size: 16),
                      label: const Text('Lobby',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final resultText = _won
                            ? 'I won the battle! Score: ${widget.playerScore}/${widget.totalQuestions}'
                            : _draw
                                ? "It's a draw! Score: ${widget.playerScore}/${widget.totalQuestions}"
                                : 'I lost the battle. Score: ${widget.playerScore}/${widget.totalQuestions}';
                        Clipboard.setData(ClipboardData(text: resultText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Result copied!')));
                      },
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SUMMARY TAB — question-by-question bar chart
// ─────────────────────────────────────────────
class _SummaryTab extends StatelessWidget {
  final List<CompeteQuestion> questions;
  final List<Map<String, dynamic>> questionLog;
  final String playerName;
  final String opponentName;

  const _SummaryTab({
    required this.questions,
    required this.questionLog,
    required this.playerName,
    required this.opponentName,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Text('QUESTION-BY-QUESTION',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            )),
        ),
        const SizedBox(height: 14),

        // Bar chart
        SizedBox(
          height: 80,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(questionLog.length, (i) {
              final log        = questionLog[i];
              final pa         = log['playerAnswer'] as int?;
              final correct    = log['correctIndex'] as int;
              final playerOk   = pa != null && pa == correct;
              final botOk      = log['botCorrect'] as bool? ?? false;

              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Player bar
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: playerOk
                              ? AppColors.teal
                              : const Color(0xFFEF4444),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Opponent bar
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: botOk
                              ? AppColors.teal
                              : const Color(0xFFEF4444),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('${i + 1}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9,
                        )),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 10),

        // Legend
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 10, height: 10,
            decoration: BoxDecoration(
              color: AppColors.teal, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          const Text('You',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(width: 16),
          Container(width: 10, height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1), shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(opponentName.length > 12
              ? '${opponentName.substring(0, 12)}…'
              : opponentName,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// REVIEW TAB — correct answers revealed
// ─────────────────────────────────────────────
class _ReviewTab extends StatelessWidget {
  final List<CompeteQuestion> questions;
  final List<Map<String, dynamic>> questionLog;

  const _ReviewTab({required this.questions, required this.questionLog});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      itemCount: questions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, qi) {
        if (qi >= questionLog.length) return const SizedBox.shrink();
        final q       = questions[qi];
        final log     = questionLog[qi];
        final pa      = log['playerAnswer'] as int?;
        final correct = log['correctIndex'] as int;
        final timeTaken = log['timeTaken'] as int? ?? 0;
        final playerOk  = pa != null && pa == correct;
        final botOk     = log['botCorrect'] as bool? ?? false;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Q header row
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Q${qi + 1}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )),
              ),
              const Spacer(),
              // You time + result
              _ReviewChip(
                label: pa == null
                    ? 'You — Opt'
                    : 'You ${timeTaken}s · ${playerOk ? "✓" : "✗"}',
                correct: playerOk,
                skipped: pa == null,
              ),
              const SizedBox(width: 6),
              // Opp result
              _ReviewChip(
                label: 'Opp ${botOk ? "✓" : "✗"}',
                correct: botOk,
                skipped: false,
              ),
            ]),
            const SizedBox(height: 10),
            Text(q.questionText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              )),
            const SizedBox(height: 10),

            // Options
            ...List.generate(q.options.length, (oi) {
              final isCorrect  = oi == correct;
              final isSelected = oi == pa;
              final isWrong    = isSelected && !isCorrect;

              Color bg = Colors.transparent;
              Color border = const Color(0xFF334155);
              if (isCorrect) {
                bg     = const Color(0xFF065F46);
                border = AppColors.teal;
              } else if (isWrong) {
                bg     = const Color(0xFF7F1D1D);
                border = AppColors.red;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border, width: 1.2),
                  ),
                  child: Row(children: [
                    Text(String.fromCharCode(65 + oi),
                      style: TextStyle(
                        color: isCorrect
                            ? AppColors.teal
                            : isWrong
                                ? AppColors.red
                                : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      )),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(q.options[oi],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        )),
                    ),
                    if (isCorrect)
                      const Icon(Icons.check_circle_rounded,
                        color: AppColors.teal, size: 16),
                    if (isWrong)
                      Icon(Icons.cancel_rounded,
                        color: AppColors.red, size: 16),
                    if (isSelected && !isWrong && !isCorrect)
                      const Text('YOU',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        )),
                  ]),
                ),
              );
            }),

            // Explanation if available
            if ((q.explanation ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_outline_rounded,
                  color: Color(0xFFF59E0B), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(q.explanation!,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    )),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Small widgets
// ─────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          )),
        const SizedBox(height: 2),
        Text(label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          )),
      ]),
    ),
  );
}

class _TabBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 13,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          )),
      ),
    ),
  );
}

class _ReviewChip extends StatelessWidget {
  final String label;
  final bool correct;
  final bool skipped;

  const _ReviewChip({
    required this.label,
    required this.correct,
    required this.skipped,
  });

  @override
  Widget build(BuildContext context) {
    final color = skipped
        ? const Color(0xFF64748B)
        : correct
            ? AppColors.teal
            : AppColors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
    );
  }
}

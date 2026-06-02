import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

typedef OnMatchFinished =
    void Function(
      CompeteMatch match,
      List<CompeteAnswer> myAnswers,
      List<CompeteAnswer> oppAnswers,
    );

// ─────────────────────────────────────────────
// BATTLE GAME SCREEN
// ─────────────────────────────────────────────
class BattleGameScreen extends StatefulWidget {
  final CompeteMatch match;
  final List<CompeteQuestion> questions;
  final String userId;
  final OnMatchFinished onFinished;

  const BattleGameScreen({
    super.key,
    required this.match,
    required this.questions,
    required this.userId,
    required this.onFinished,
  });

  @override
  State<BattleGameScreen> createState() => _BattleGameScreenState();
}

class _BattleGameScreenState extends State<BattleGameScreen> {
  final _db = Supabase.instance.client;

  late CompeteMatch _match;
  late List<CompeteQuestion> _questions;

  int? _selectedIndex;
  int _timeLeftMs = 30000;
  Timer? _timer;
  DateTime? _questionStartedAt;
  bool _submitted = false;
  final Set<int> _submittedIndices = {};

  final List<CompeteAnswer> _myAnswers = [];
  final List<CompeteAnswer> _allAnswers = [];

  Timer? _botTimer;
  CompeteAnswer? _pendingBotAnswer;

  RealtimeChannel? _channel;

  // ── Derived getters ──────────────────────────────────────────────────────
  bool get _imP1 => widget.match.player1Id == widget.userId;
  String get _myName => _imP1
      ? (widget.match.player1Name ?? 'You')
      : (widget.match.player2Name ?? 'You');
  String get _oppName => _imP1
      ? (widget.match.player2Name ??
            (_match.isBot ? 'AI Opponent' : 'Opponent'))
      : (widget.match.player1Name ?? 'Opponent');
  int get _myScore => _imP1 ? _match.player1Score : _match.player2Score;
  int get _oppScore => _imP1 ? _match.player2Score : _match.player1Score;
  int get _curIdx => _match.currentQuestionIndex;

  // Timer color: orange → warning → error
  Color get _timerColor => _timeLeftMs > 15000
      ? DS.primary
      : _timeLeftMs > 5000
      ? DS.warning
      : DS.error;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _questions = widget.questions.take(10).toList();
    _startQuestionTimer();
    if (!_match.isBot) {
      _subscribeRealtime();
      _loadExistingAnswers();
    } else {
      _scheduleBotAnswer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _botTimer?.cancel();
    if (_channel != null) _db.removeChannel(_channel!);
    super.dispose();
  }

  // ── Realtime ──────────────────────────────────────────────────────────────
  Future<void> _loadExistingAnswers() async {
    try {
      final rows = await _db
          .from('compete_match_answers')
          .select()
          .eq('match_id', _match.id);
      for (final r in (rows as List)) {
        final a = CompeteAnswer.fromJson(r as Map<String, dynamic>);
        if (!_allAnswers.any(
          (x) => x.userId == a.userId && x.questionIndex == a.questionIndex,
        )) {
          _allAnswers.add(a);
          if (a.userId == widget.userId) _myAnswers.add(a);
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _subscribeRealtime() {
    _channel = _db.channel('compete-match-${_match.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'compete_matches',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: _match.id,
        ),
        callback: _onMatchUpdate,
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'compete_match_answers',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'match_id',
          value: _match.id,
        ),
        callback: _onAnswerInsert,
      )
      ..subscribe();
  }

  void _onMatchUpdate(PostgresChangePayload payload) {
    if (!mounted) return;
    final raw = CompeteMatch.fromJson(payload.newRecord);
    final updated = raw.copyWithProfiles(
      player1Name: raw.player1Name?.isNotEmpty == true
          ? raw.player1Name
          : _match.player1Name,
      player1Avatar: raw.player1Avatar ?? _match.player1Avatar,
      player2Name: raw.player2Name?.isNotEmpty == true
          ? raw.player2Name
          : _match.player2Name,
      player2Avatar: raw.player2Avatar ?? _match.player2Avatar,
    );
    if (updated.status == 'finished') {
      setState(() => _match = updated);
      _finishMatch();
      return;
    }
    if (updated.currentQuestionIndex > _curIdx) {
      setState(() => _match = updated);
      _resetForNewQuestion();
    } else {
      setState(() => _match = updated);
    }
  }

  void _onAnswerInsert(PostgresChangePayload payload) {
    if (!mounted) return;
    final answer = CompeteAnswer.fromJson(payload.newRecord);
    if (_allAnswers.any(
      (x) =>
          x.userId == answer.userId && x.questionIndex == answer.questionIndex,
    ))
      return;
    setState(() {
      _allAnswers.add(answer);
      if (answer.userId == widget.userId) {
        if (!_myAnswers.any((x) => x.questionIndex == answer.questionIndex))
          _myAnswers.add(answer);
      }
    });
    final oppId = _imP1 ? _match.player2Id : _match.player1Id;
    final myAnswered = _allAnswers.any(
      (x) => x.userId == widget.userId && x.questionIndex == _curIdx,
    );
    final oppAnswered = _allAnswers.any(
      (x) => x.userId == (oppId ?? '') && x.questionIndex == _curIdx,
    );
    if (myAnswered && oppAnswered) {
      if (!_submittedIndices.contains(_curIdx - 1)) _scheduleAdvance();
    }
  }

  // ── Timer ─────────────────────────────────────────────────────────────────
  void _startQuestionTimer() {
    _timer?.cancel();
    _submitted = false;
    _selectedIndex = null;
    final started = _match.currentQuestionStartedAt ?? DateTime.now();
    _questionStartedAt = started;
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    _timeLeftMs = max(0, 30000 - elapsed);

    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final e = DateTime.now().difference(_questionStartedAt!).inMilliseconds;
      final left = max(0, 30000 - e);
      setState(() => _timeLeftMs = left);
      if (left <= 0 && !_submitted) {
        t.cancel();
        _autoSubmit();
      }
    });
  }

  void _resetForNewQuestion() {
    _timer?.cancel();
    _botTimer?.cancel();
    _submitted = false;
    _selectedIndex = null;
    _startQuestionTimer();
    if (_match.isBot) _scheduleBotAnswer();
  }

  // ── Bot ───────────────────────────────────────────────────────────────────
  void _scheduleBotAnswer() {
    _botTimer?.cancel();
    _pendingBotAnswer = null;
    final qIdx = _curIdx;
    final q = _questions[qIdx];
    final delayMs = 2000 + Random().nextInt(10000);
    final botCorrect = Random().nextDouble() < 0.65;
    final botIdx = botCorrect
        ? q.correct
        : (q.correct + 1 + Random().nextInt(3)) % 4;
    final botPoints = botCorrect
        ? (100 + max(0, 100 - (delayMs / 30000 * 100))).round()
        : 0;
    _pendingBotAnswer = CompeteAnswer(
      matchId: _match.id,
      userId: kBotUserId,
      questionIndex: qIdx,
      selectedIndex: botIdx,
      isCorrect: botCorrect,
      points: botPoints,
      timeTakenMs: delayMs,
    );
    _botTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) _commitBotAnswer();
    });
  }

  void _commitBotAnswer() {
    final pending = _pendingBotAnswer;
    if (pending == null) return;
    _pendingBotAnswer = null;
    if (!mounted) return;
    setState(() {
      _allAnswers.add(pending);
      _match = _match.copyWith(
        player2Score: _imP1
            ? _match.player2Score + pending.points
            : _match.player2Score,
        player1Score: !_imP1
            ? _match.player1Score + pending.points
            : _match.player1Score,
      );
    });
  }

  // ── Answer logic ──────────────────────────────────────────────────────────
  void _selectAnswer(int idx) {
    if (_submitted || _submittedIndices.contains(_curIdx)) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = idx);
    _submitAnswer(idx);
  }

  void _autoSubmit() {
    if (_submitted || _submittedIndices.contains(_curIdx)) return;
    _submitAnswer(null);
  }

  void _scheduleAdvance() {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _advanceOrFinish();
    });
  }

  void _submitAnswer(int? selectedIdx) {
    if (_submitted || _submittedIndices.contains(_curIdx)) return;
    _submitted = true;
    _submittedIndices.add(_curIdx);
    _timer?.cancel();

    final q = _questions[_curIdx];
    final timeTakenMs = DateTime.now()
        .difference(_questionStartedAt!)
        .inMilliseconds
        .clamp(0, 30000);
    final isCorrect = selectedIdx != null && selectedIdx == q.correct;
    final points = isCorrect
        ? (100 + max(0.0, 100.0 - (timeTakenMs / 30000.0) * 100.0)).round()
        : 0;

    final answer = CompeteAnswer(
      matchId: _match.id,
      userId: widget.userId,
      questionIndex: _curIdx,
      selectedIndex: selectedIdx,
      isCorrect: isCorrect,
      points: points,
      timeTakenMs: timeTakenMs,
    );

    setState(() {
      _myAnswers.add(answer);
      _allAnswers.add(answer);
      _match = _match.copyWith(
        player1Score: _imP1
            ? _match.player1Score + points
            : _match.player1Score,
        player2Score: !_imP1
            ? _match.player2Score + points
            : _match.player2Score,
      );
    });

    if (_match.isBot) {
      _botTimer?.cancel();
      _commitBotAnswer();
      _scheduleAdvance();
      _submitToServer(selectedIdx, isCorrect, points, timeTakenMs);
    } else {
      _submitToServerP2P(selectedIdx, isCorrect, points, timeTakenMs);
    }
  }

  Future<void> _submitToServer(int? sel, bool ok, int pts, int ms) async {
    try {
      await _db.functions.invoke(
        'compete-submit-answer',
        body: {
          'match_id': _match.id,
          'question_index': _curIdx,
          'selected_index': sel,
          'time_taken_ms': ms,
        },
      );
    } catch (_) {
      try {
        await _db.from('compete_match_answers').upsert({
          'match_id': _match.id,
          'user_id': widget.userId,
          'question_index': _curIdx,
          'selected_index': sel,
          'is_correct': ok,
          'points': pts,
          'time_taken_ms': ms,
        });
      } catch (_) {}
    }
  }

  void _submitToServerP2P(int? sel, bool ok, int pts, int ms) async {
    _scheduleAdvance();
    _submitToServer(sel, ok, pts, ms);
  }

  int _lastAdvancedIndex = -1;

  void _advanceOrFinish() {
    if (!mounted) return;
    if (_curIdx == _lastAdvancedIndex) return;
    _lastAdvancedIndex = _curIdx;
    if (_curIdx >= _questions.length - 1) {
      _finishMatch();
      return;
    }
    final nextIdx = _curIdx + 1;
    final nextStart = DateTime.now();
    setState(() {
      _match = _match.copyWith(
        currentQuestionIndex: nextIdx,
        currentQuestionStartedAt: nextStart,
      );
    });
    _resetForNewQuestion();
    if (!_match.isBot && _imP1) {
      _db
          .from('compete_matches')
          .update({
            'current_question_index': nextIdx,
            'current_question_started_at': nextStart.toUtc().toIso8601String(),
          })
          .eq('id', _match.id)
          .then((_) {})
          .catchError((_) {});
    }
  }

  void _finishMatch() {
    if (!mounted) return;
    _timer?.cancel();
    _botTimer?.cancel();
    if (_match.isBot) {
      final winnerId = _myScore > _oppScore
          ? widget.userId
          : _myScore < _oppScore
          ? kBotUserId
          : null;
      final finished = _match.copyWith(status: 'finished', winnerId: winnerId);
      final botAnswers = _allAnswers
          .where((a) => a.userId == kBotUserId)
          .toList();
      widget.onFinished(finished, _myAnswers, botAnswers);
    } else {
      _fetchAndFinishP2P();
    }
  }

  Future<void> _fetchAndFinishP2P() async {
    CompeteMatch finished = _match;
    try {
      final row = await _db
          .from('compete_matches')
          .select()
          .eq('id', _match.id)
          .single();
      final fromDb = CompeteMatch.fromJson(row);
      final p1 = fromDb.player1Score > 0 || fromDb.player2Score > 0
          ? fromDb.player1Score
          : _match.player1Score;
      final p2 = fromDb.player1Score > 0 || fromDb.player2Score > 0
          ? fromDb.player2Score
          : _match.player2Score;
      final myFinal = _imP1 ? p1 : p2;
      final oppFinal = _imP1 ? p2 : p1;
      String? winnerId = fromDb.winnerId;
      if (winnerId == null || winnerId.isEmpty) {
        if (myFinal > oppFinal)
          winnerId = widget.userId;
        else if (oppFinal > myFinal)
          winnerId = _imP1 ? fromDb.player2Id : fromDb.player1Id;
      }
      finished = fromDb
          .copyWith(
            player1Score: p1,
            player2Score: p2,
            status: 'finished',
            winnerId: winnerId,
          )
          .copyWithProfiles(
            player1Name: _match.player1Name,
            player1Avatar: _match.player1Avatar,
            player2Name: _match.player2Name,
            player2Avatar: _match.player2Avatar,
          );
    } catch (_) {
      final winnerId = _myScore > _oppScore
          ? widget.userId
          : _myScore < _oppScore
          ? (_imP1 ? _match.player2Id : _match.player1Id)
          : null;
      finished = _match.copyWith(status: 'finished', winnerId: winnerId);
    }
    if (mounted) widget.onFinished(finished, _myAnswers, const []);
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_curIdx >= _questions.length) {
      return Scaffold(
        backgroundColor: DS.background,
        body: const Center(
          child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
        ),
      );
    }

    final q = _questions[_curIdx];
    final timeLeftSec = (_timeLeftMs / 1000).ceil();
    final timeFrac = (_timeLeftMs / 30000).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: Column(
          children: [
            // ── Gradient score header ──
            _ScoreHeader(
              myName: _myName,
              oppName: _oppName,
              myScore: _myScore,
              oppScore: _oppScore,
              curIdx: _curIdx,
              total: _questions.length,
              subject: _match.subject,
              topic: _match.topic.isEmpty ? 'Any' : _match.topic,
            ),

            // ── Timer bar ──
            _TimerBar(
              timeFrac: timeFrac,
              timeLeftSec: timeLeftSec,
              timerColor: _timerColor,
            ),

            // ── Question + options ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DS.s16,
                  DS.s16,
                  DS.s16,
                  DS.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question card
                    _QuestionCard(question: q, index: _curIdx),
                    const SizedBox(height: DS.s14),

                    // Options
                    ...List.generate(
                      q.options.length,
                      (i) => _OptionTile(
                        index: i,
                        text: q.options[i],
                        selected: _selectedIndex == i,
                        locked: _submitted,
                        isCorrect: false,
                        isWrong: false,
                        onTap: _submitted ? null : () => _selectAnswer(i),
                      ),
                    ),

                    // Skip
                    if (!_submitted)
                      Center(
                        child: TextButton.icon(
                          onPressed: _autoSubmit,
                          icon: const Icon(
                            Icons.skip_next_rounded,
                            size: 16,
                            color: DS.textSecondary,
                          ),
                          label: const Text(
                            'Skip',
                            style: TextStyle(
                              color: DS.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
// SCORE HEADER
// ─────────────────────────────────────────────
class _ScoreHeader extends StatelessWidget {
  final String myName, oppName, subject, topic;
  final int myScore, oppScore, curIdx, total;

  const _ScoreHeader({
    required this.myName,
    required this.oppName,
    required this.myScore,
    required this.oppScore,
    required this.curIdx,
    required this.total,
    required this.subject,
    required this.topic,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
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
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                DS.s16,
                DS.s12,
                DS.s16,
                DS.s20,
              ),
              child: Row(
                children: [
                  // My score (left)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          myName.length > 10
                              ? '${myName.substring(0, 10)}…'
                              : myName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 11.5,
                          ),
                        ),
                        Text(
                          '$myScore',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'pts',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.60),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center: Q counter + subject
                  Column(
                    children: [
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
                          'Q ${curIdx + 1} / $total',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: DS.s4),
                      Text(
                        '$subject · $topic',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.60),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),

                  // Opponent score (right)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          oppName.length > 10
                              ? '${oppName.substring(0, 10)}…'
                              : oppName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.78),
                            fontSize: 11.5,
                          ),
                        ),
                        Text(
                          '$oppScore',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.70),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'pts',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.50),
                            fontSize: 10.5,
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
          top: -40,
          right: -25,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 20,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TIMER BAR
// ─────────────────────────────────────────────
class _TimerBar extends StatelessWidget {
  final double timeFrac;
  final int timeLeftSec;
  final Color timerColor;

  const _TimerBar({
    required this.timeFrac,
    required this.timeLeftSec,
    required this.timerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s14, DS.s16, DS.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Timer icon + seconds
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s10,
                  vertical: DS.s4,
                ),
                decoration: BoxDecoration(
                  color: timerColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: timerColor.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, color: timerColor, size: 13),
                    const SizedBox(width: DS.s4),
                    Text(
                      '${timeLeftSec}s',
                      style: TextStyle(
                        color: timerColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: DS.s10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: timeFrac,
                    minHeight: 7,
                    backgroundColor: DS.border,
                    color: timerColor,
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
// QUESTION CARD
// ─────────────────────────────────────────────
class _QuestionCard extends StatelessWidget {
  final CompeteQuestion question;
  final int index;

  const _QuestionCard({required this.question, required this.index});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
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
        // Q badge
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
            'Q${index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: DS.s12),

        // Question text
        MathHtmlWidget(
          question.questionText,
          textStyle: const TextStyle(
            color: DS.textPrimary,
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            height: 1.55,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// OPTION TILE
// ─────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final int index;
  final String text;
  final bool selected, locked, isCorrect, isWrong;
  final VoidCallback? onTap;

  static const _letters = ['A', 'B', 'C', 'D'];

  const _OptionTile({
    required this.index,
    required this.text,
    required this.selected,
    required this.locked,
    required this.isCorrect,
    required this.isWrong,
    this.onTap,
  });

  Color get _bgColor {
    if (isCorrect) return DS.successSurface;
    if (isWrong) return DS.errorSurface;
    if (selected) return DS.primaryLight;
    return DS.surface;
  }

  Color get _borderColor {
    if (isCorrect) return DS.success;
    if (isWrong) return DS.error;
    if (selected) return DS.primary;
    return DS.border;
  }

  Color get _letterColor {
    if (isCorrect) return DS.success;
    if (isWrong) return DS.error;
    if (selected) return DS.primary;
    return DS.textSecondary;
  }

  Color get _textColor {
    if (isCorrect) return DS.success;
    if (isWrong) return DS.error;
    if (selected) return DS.primaryDark;
    return DS.textPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final label = index < _letters.length ? _letters[index] : '${index + 1}';

    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s14,
            vertical: DS.s12,
          ),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(DS.radiusMd),
            border: Border.all(
              color: _borderColor,
              width: selected || isCorrect || isWrong ? 1.8 : 1.2,
            ),
            boxShadow: selected && !locked
                ? [
                    BoxShadow(
                      color: DS.primary.withOpacity(0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : isCorrect
                ? [
                    BoxShadow(
                      color: DS.success.withOpacity(0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Letter badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: selected && !locked && !isCorrect && !isWrong
                      ? const LinearGradient(
                          colors: [Color(0xFFFF8C38), DS.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isCorrect
                      ? DS.success.withOpacity(0.15)
                      : isWrong
                      ? DS.error.withOpacity(0.15)
                      : selected
                      ? null
                      : DS.surfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _borderColor.withOpacity(0.40),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected && !locked && !isCorrect && !isWrong
                          ? Colors.white
                          : _letterColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DS.s12),

              // Option text
              Expanded(
                child: MathHtmlWidget(
                  text,
                  textStyle: TextStyle(
                    color: _textColor,
                    fontSize: 14.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ),

              // Status icon (after submit)
              if (isCorrect)
                const Padding(
                  padding: EdgeInsets.only(left: DS.s8),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: DS.success,
                    size: 18,
                  ),
                ),
              if (isWrong)
                const Padding(
                  padding: EdgeInsets.only(left: DS.s8),
                  child: Icon(Icons.cancel_rounded, color: DS.error, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

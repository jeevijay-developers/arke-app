import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/colors.dart';
import 'compete_models.dart';
import 'compete_question.dart';
import 'battle_game_screen.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────
const _bg = Color(0xFF0F172A);
const _card = Color(0xFF1E293B);
const _border = Color(0xFF334155);
const _muted = Color(0xFF94A3B8);

// ─────────────────────────────────────────────
// BattleLobbyScreen
// ─────────────────────────────────────────────
class BattleLobbyScreen extends ConsumerStatefulWidget {
  const BattleLobbyScreen({super.key});

  @override
  ConsumerState<BattleLobbyScreen> createState() => _BattleLobbyScreenState();
}

class _BattleLobbyScreenState extends ConsumerState<BattleLobbyScreen> {
  final _db = Supabase.instance.client;

  // ── Filter state ──────────────────────────────────────────────────────────
  static const _classList = ['6', '7', '8', '9', '10', '11', '12', 'Dropper'];
  static const _examList = [
    'JEE Main',
    'JEE Advanced',
    'NEET',
    'Boards',
    'Foundation',
  ];
  static const _subjectMap = {
    'JEE Main': ['Physics', 'Chemistry', 'Math'],
    'JEE Advanced': ['Physics', 'Chemistry', 'Math'],
    'NEET': ['Physics', 'Chemistry', 'Biology'],
    'Boards': ['Physics', 'Chemistry', 'Math', 'Biology'],
    'Foundation': ['Physics', 'Chemistry', 'Math', 'Biology'],
  };

  String _selectedClass = '11';
  String _selectedExam = 'JEE Main';
  String _selectedSubject = 'Physics';
  String _selectedTopic = 'Any';

  List<String> _topics = ['Any'];
  bool _loadingTopics = false;

  // ── Stats ─────────────────────────────────────────────────────────────────
  int _rating = 1000;
  int _wins = 0;
  int _streak = 0;
  bool _loadingStats = false;

  // ── Matchmaking state ─────────────────────────────────────────────────────
  final _roomCodeCtrl = TextEditingController();
  bool _findingOpponent = false;
  bool _creatingRoom = false;
  bool _loadingBotGame = false;
  bool _joiningRoom = false;
  String? _createdRoomCode;

  RealtimeChannel? _queueChannel;
  RealtimeChannel? _matchChannel;
  String? _myQueueId;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadProfilePreferences();
    _loadStats();
    _loadTopics();
  }

  @override
  void dispose() {
    _roomCodeCtrl.dispose();
    _cancelQueue();
    _queueChannel?.unsubscribe();
    _matchChannel?.unsubscribe();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String get _userId => _db.auth.currentUser?.id ?? '';
  String get _userName =>
      _db.auth.currentUser?.userMetadata?['full_name'] as String? ?? 'Student';

  List<String> get _availableSubjects =>
      _subjectMap[_selectedExam] ?? ['Physics', 'Chemistry', 'Math', 'Biology'];

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _truncate(String s) => s.length > 14 ? '${s.substring(0, 14)}…' : s;

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Load profile preferences ──────────────────────────────────────────────
  Future<void> _loadProfilePreferences() async {
    if (_userId.isEmpty) return;
    try {
      final data = await _db
          .from('profiles')
          .select('class_level, target_exam')
          .eq('user_id', _userId)
          .maybeSingle();
      if (data == null || !mounted) return;

      final cl = data['class_level'] as String?;
      final te = data['target_exam'] as String?;

      setState(() {
        if (cl != null && _classList.contains(cl)) _selectedClass = cl;
        if (te != null && _examList.contains(te)) _selectedExam = te;
        // Ensure selected subject is valid for the exam
        if (!_availableSubjects.contains(_selectedSubject)) {
          _selectedSubject = _availableSubjects.first;
        }
      });
      _loadTopics();
    } catch (_) {}
  }

  // ── Load real stats ───────────────────────────────────────────────────────
  Future<void> _loadStats() async {
    if (_userId.isEmpty) return;
    setState(() => _loadingStats = true);
    try {
      // Finished matches where this user participated
      final matches = await _db
          .from('compete_matches')
          .select(
            'winner_id, player1_id, player2_id, player1_rating_after, player2_rating_after, status',
          )
          .or('player1_id.eq.$_userId,player2_id.eq.$_userId')
          .eq('status', 'finished')
          .order('created_at', ascending: false);

      if (!mounted) return;

      int wins = 0;
      int streak = 0;
      int rating = 1000;
      bool streakBroken = false;

      for (final m in (matches as List)) {
        final isP1 = m['player1_id'] == _userId;
        final winnerId = m['winner_id'] as String?;
        final won = winnerId == _userId;

        // Latest rating
        if (rating == 1000) {
          final after = isP1
              ? m['player1_rating_after']
              : m['player2_rating_after'];
          if (after != null) rating = after as int;
        }

        if (won) {
          wins++;
          if (!streakBroken) streak++;
        } else {
          streakBroken = true;
        }
      }

      setState(() {
        _rating = rating;
        _wins = wins;
        _streak = streak;
        _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  // ── Load topics ───────────────────────────────────────────────────────────
  Future<void> _loadTopics() async {
    setState(() {
      _loadingTopics = true;
      _topics = ['Any'];
      _selectedTopic = 'Any';
    });
    try {
      var query = _db
          .from('compete_questions')
          .select('topic')
          .eq('subject', _selectedSubject)
          .eq('is_active', true);

      if (_selectedClass != 'Any')
        query = query.eq('class_level', _selectedClass);
      if (_selectedExam != 'Any')
        query = query.eq('target_exam', _selectedExam);

      final data = await query;
      final topics =
          (data as List)
              .map((r) => r['topic'] as String)
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (mounted)
        setState(() {
          _topics = ['Any', ...topics];
          _loadingTopics = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loadingTopics = false);
    }
  }

  // ── Fetch questions matching preferences ──────────────────────────────────
  // Returns (questions, usedFallback). Falls back to subject-only if the
  // exact class+exam combo has no questions, so bot games always work.
  Future<(List<CompeteQuestion>, bool)> _fetchQuestionsWithFallback() async {
    final exact = await _fetchQuestionsRaw(
      classLevel: _selectedClass,
      targetExam: _selectedExam,
    );
    if (exact.isNotEmpty) return (exact, false);

    // Fallback: ignore class_level & target_exam, match subject only
    final fallback = await _fetchQuestionsRaw(
      classLevel: null,
      targetExam: null,
    );
    return (fallback, true);
  }

  Future<List<CompeteQuestion>> _fetchQuestions() async {
    final (questions, _) = await _fetchQuestionsWithFallback();
    return questions;
  }

  Future<List<CompeteQuestion>> _fetchQuestionsRaw({
    required String? classLevel,
    required String? targetExam,
  }) async {
    var query = _db
        .from('compete_questions')
        .select(
          'id, subject, topic, difficulty, question_text, options, correct_index, explanation',
        )
        .eq('subject', _selectedSubject)
        .eq('is_active', true);

    if (_selectedTopic != 'Any' && _selectedTopic.isNotEmpty) {
      query = query.eq('topic', _selectedTopic);
    }
    if (classLevel != null && classLevel != 'Any') {
      query = query.eq('class_level', classLevel);
    }
    if (targetExam != null && targetExam != 'Any') {
      query = query.eq('target_exam', targetExam);
    }

    final data = await query;
    final all = (data as List)
        .map((r) => CompeteQuestion.fromJson(r as Map<String, dynamic>))
        .toList();
    all.shuffle(Random());
    return all.take(10).toList();
  }

  Future<List<CompeteQuestion>> _fetchQuestionsByIds(List<String> ids) async {
    if (ids.isEmpty) return _fetchQuestions();
    final data = await _db
        .from('compete_questions')
        .select(
          'id, subject, topic, difficulty, question_text, options, correct_index, explanation',
        )
        .inFilter('id', ids);
    final list = (data as List)
        .map((r) => CompeteQuestion.fromJson(r as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    return list;
  }

  // ── Queue cleanup ─────────────────────────────────────────────────────────
  Future<void> _cancelQueue() async {
    if (_myQueueId != null) {
      await _db.from('compete_queue').delete().eq('id', _myQueueId!);
      _myQueueId = null;
    }
  }

  // ── Navigate to battle ────────────────────────────────────────────────────
  void _goToBattle({
    required String matchId,
    required List<CompeteQuestion> questions,
    required String opponentName,
    required bool isBot,
    String? roomCode,
  }) {
    if (!mounted) return;
    final match = CompeteMatch(
      id: matchId,
      player1Id: _userId,
      player1Name: _userName,
      player2Id: isBot ? kBotUserId : null,
      player2Name: opponentName,
      subject: _selectedSubject,
      topic: _selectedTopic == 'Any' ? '' : _selectedTopic,
      questionIds: questions.map((q) => q.id).toList(),
      totalQuestions: questions.length,
      status: 'active',
      isBot: isBot,
      isPrivate: roomCode != null,
      roomCode: roomCode,
      currentQuestionStartedAt: DateTime.now(),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattleGameScreen(
          match: match,
          questions: questions,
          userId: _userId,
          onFinished: (_, _) =>
              Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ),
    );
  }

  // ── Practice vs Bot ───────────────────────────────────────────────────────
  Future<void> _practiceVsBot() async {
    setState(() => _loadingBotGame = true);
    try {
      final (questions, usedFallback) = await _fetchQuestionsWithFallback();
      if (!mounted) return;
      if (questions.isEmpty) {
        _showSnack(
          'No questions available. Please ask your admin to add questions.',
        );
        return;
      }
      if (usedFallback) {
        _showSnack(
          'No questions for this exact class/exam — using $_selectedSubject questions instead.',
        );
      }
      final localMatchId = 'bot_${DateTime.now().millisecondsSinceEpoch}';
      _goToBattle(
        matchId: localMatchId,
        questions: questions,
        opponentName: 'Bot',
        isBot: true,
      );
    } catch (e) {
      if (mounted) _showSnack('Failed to load questions: $e');
    } finally {
      if (mounted) setState(() => _loadingBotGame = false);
    }
  }

  // ── Find Opponent ─────────────────────────────────────────────────────────
  Future<void> _findOpponent() async {
    if (_userId.isEmpty) {
      _showSnack('Not signed in');
      return;
    }
    setState(() => _findingOpponent = true);
    try {
      // Look for someone waiting with same subject + class + exam
      var query = _db
          .from('compete_queue')
          .select()
          .eq('subject', _selectedSubject)
          .eq('status', 'waiting')
          .neq('user_id', _userId);

      if (_selectedClass != 'Any')
        query = query.eq('class_level', _selectedClass);
      if (_selectedExam != 'Any')
        query = query.eq('target_exam', _selectedExam);

      final waiting = await query.order('created_at').limit(1);

      if (waiting.isNotEmpty) {
        await _matchWithOpponent(waiting.first);
      } else {
        await _joinQueueAndWait();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _findingOpponent = false);
        _showSnack(
          e.toString().contains('42501')
              ? 'Permission denied. Ask admin to enable compete access.'
              : 'Error: $e',
        );
      }
    }
  }

  Future<void> _matchWithOpponent(Map<String, dynamic> opponent) async {
    final opponentQueueId = opponent['id'] as String;
    final opponentId = opponent['user_id'] as String;
    final opponentName = opponent['user_name'] as String? ?? 'Opponent';

    await _db
        .from('compete_queue')
        .update({'status': 'matched'})
        .eq('id', opponentQueueId);

    final (questions, _) = await _fetchQuestionsWithFallback();
    final questionIds = questions.map((q) => q.id).toList();

    final res = await _db
        .from('compete_matches')
        .insert({
          'player1_id': _userId,
          'player1_name': _userName,
          'player2_id': opponentId,
          'player2_name': opponentName,
          'subject': _selectedSubject,
          'topic': _selectedTopic == 'Any' ? '' : _selectedTopic,
          'question_ids': questionIds,
          'total_questions': questions.length,
          'status': 'active',
          'is_bot': false,
          'is_private': false,
          'player1_rating_before': _rating,
          'started_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    final matchId = res['id'] as String;
    await _db
        .from('compete_queue')
        .update({'match_id': matchId})
        .eq('id', opponentQueueId);

    if (mounted) setState(() => _findingOpponent = false);
    _goToBattle(
      matchId: matchId,
      questions: questions,
      opponentName: _truncate(opponentName),
      isBot: false,
    );
  }

  Future<void> _joinQueueAndWait() async {
    final res = await _db
        .from('compete_queue')
        .insert({
          'user_id': _userId,
          'subject': _selectedSubject,
          'topic': _selectedTopic == 'Any' ? '' : _selectedTopic,
          'class_level': _selectedClass,
          'target_exam': _selectedExam,
          'rating': _rating,
          'status': 'waiting',
        })
        .select('id')
        .single();

    _myQueueId = res['id'] as String;

    _queueChannel = _db
        .channel('queue_${_myQueueId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'compete_queue',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _myQueueId!,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            final matchId = row['match_id'] as String?;
            if (matchId != null && mounted) {
              _queueChannel?.unsubscribe();
              _myQueueId = null;
              await _loadMatchAndNavigate(matchId, isCreator: false);
            }
          },
        )
        .subscribe();

    // 30 second timeout
    Future.delayed(const Duration(seconds: 30), () async {
      if (mounted && _findingOpponent) {
        await _cancelQueue();
        _queueChannel?.unsubscribe();
        if (mounted) {
          setState(() => _findingOpponent = false);
          _showNoOpponentDialog();
        }
      }
    });
  }

  Future<void> _loadMatchAndNavigate(
    String matchId, {
    required bool isCreator,
  }) async {
    try {
      final match = await _db
          .from('compete_matches')
          .select('question_ids, player1_name, player2_name, is_bot')
          .eq('id', matchId)
          .single();

      final questionIds = (match['question_ids'] as List)
          .map((e) => e.toString())
          .toList();
      final questions = await _fetchQuestionsByIds(questionIds);
      final opponentName = isCreator
          ? _truncate(match['player2_name'] as String? ?? 'Opponent')
          : _truncate(match['player1_name'] as String? ?? 'Opponent');

      if (mounted) setState(() => _findingOpponent = false);
      _goToBattle(
        matchId: matchId,
        questions: questions,
        opponentName: opponentName,
        isBot: false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _findingOpponent = false);
        _showSnack('Failed to start match: $e');
      }
    }
  }

  // ── Create Room ───────────────────────────────────────────────────────────
  Future<void> _createRoom() async {
    if (_userId.isEmpty) {
      _showSnack('Not signed in');
      return;
    }
    setState(() => _creatingRoom = true);
    try {
      final (questions, usedFallback) = await _fetchQuestionsWithFallback();
      if (questions.isEmpty) {
        _showSnack('No questions available. Ask your admin to add questions.');
        setState(() => _creatingRoom = false);
        return;
      }
      if (usedFallback) {
        _showSnack(
          'No questions for this class/exam — using $_selectedSubject questions instead.',
        );
      }

      final code = _generateCode();
      final questionIds = questions.map((q) => q.id).toList();

      final res = await _db
          .from('compete_matches')
          .insert({
            'player1_id': _userId,
            'player1_name': _userName,
            'subject': _selectedSubject,
            'topic': _selectedTopic == 'Any' ? '' : _selectedTopic,
            'question_ids': questionIds,
            'total_questions': questions.length,
            'status': 'pending',
            'is_private': true,
            'is_bot': false,
            'room_code': code,
            'player1_rating_before': _rating,
          })
          .select('id')
          .single();

      final matchId = res['id'] as String;
      setState(() => _createdRoomCode = code);

      _matchChannel = _db
          .channel('match_$matchId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'compete_matches',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'id',
              value: matchId,
            ),
            callback: (payload) {
              final row = payload.newRecord;
              final p2 = row['player2_id'] as String?;
              final status = row['status'] as String?;
              if (p2 != null &&
                  p2.isNotEmpty &&
                  status == 'active' &&
                  mounted) {
                _matchChannel?.unsubscribe();
                setState(() {
                  _creatingRoom = false;
                  _createdRoomCode = null;
                });
                _goToBattle(
                  matchId: matchId,
                  questions: questions,
                  opponentName: _truncate(
                    row['player2_name'] as String? ?? 'Opponent',
                  ),
                  isBot: false,
                  roomCode: code,
                );
              }
            },
          )
          .subscribe();
    } catch (e) {
      if (mounted) {
        setState(() => _creatingRoom = false);
        _showSnack(
          e.toString().contains('42501')
              ? 'Permission denied. Ask admin to enable compete access.'
              : 'Error creating room: $e',
        );
      }
    }
  }

  // ── Join Room ─────────────────────────────────────────────────────────────
  Future<void> _joinRoom() async {
    final code = _roomCodeCtrl.text.trim().toUpperCase();
    if (code.length < 4) {
      _showSnack('Enter a valid room code');
      return;
    }
    if (_userId.isEmpty) {
      _showSnack('Not signed in');
      return;
    }

    setState(() => _joiningRoom = true);
    try {
      final data = await _db
          .from('compete_matches')
          .select()
          .eq('room_code', code)
          .eq('status', 'pending')
          .limit(1);

      if (data.isEmpty) {
        _showSnack('Room not found or already started.');
        setState(() => _joiningRoom = false);
        return;
      }

      final match = data.first;
      final matchId = match['id'] as String;
      final questionIds = (match['question_ids'] as List)
          .map((e) => e.toString())
          .toList();
      final questions = await _fetchQuestionsByIds(questionIds);
      final hostName = match['player1_name'] as String? ?? 'Host';

      await _db
          .from('compete_matches')
          .update({
            'player2_id': _userId,
            'player2_name': _userName,
            'player2_rating_before': _rating,
            'status': 'active',
            'started_at': DateTime.now().toIso8601String(),
          })
          .eq('id', matchId);

      if (mounted) setState(() => _joiningRoom = false);
      _goToBattle(
        matchId: matchId,
        questions: questions,
        opponentName: _truncate(hostName),
        isBot: false,
        roomCode: code,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _joiningRoom = false);
        _showSnack('Error joining room: $e');
      }
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────
  void _showNoOpponentDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'No opponent found',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'No one with the same preferences is available.\nWant to practice vs Bot instead?',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _practiceVsBot();
            },
            child: const Text(
              'Play vs Bot',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Back + title ──────────────────────────────────────────
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        await _cancelQueue();
                        if (!mounted) return;
                        final router = GoRouter.of(
                          context,
                        ); // ignore: use_build_context_synchronously
                        if (router.canPop()) {
                          Navigator.of(
                            context,
                          ).pop(); // ignore: use_build_context_synchronously
                        } else {
                          router.go('/compete');
                        }
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Battle Arena',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Hero card ─────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8C38), AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.sports_kabaddi_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Compete',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Battle a peer · 10 questions · 30s each',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Stats row ─────────────────────────────────────────────
                Row(
                  children: [
                    _StatChip(
                      icon: '🏆',
                      label: 'RATING',
                      value: _loadingStats ? '…' : '$_rating',
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      icon: '⭐',
                      label: 'WINS',
                      value: _loadingStats ? '…' : '$_wins',
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      icon: '🔥',
                      label: 'STREAK',
                      value: _loadingStats ? '…' : '$_streak',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── CLASS filter ──────────────────────────────────────────
                _FilterLabel(label: 'CLASS'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _classList
                      .map(
                        (c) => _Chip(
                          label: c == 'Dropper' ? 'Dropper' : 'Class $c',
                          selected: _selectedClass == c,
                          onTap: () {
                            setState(() => _selectedClass = c);
                            _loadTopics();
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),

                // ── EXAM filter ───────────────────────────────────────────
                _FilterLabel(label: 'EXAM'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _examList
                      .map(
                        (e) => _Chip(
                          label: e,
                          selected: _selectedExam == e,
                          onTap: () {
                            setState(() {
                              _selectedExam = e;
                              // Reset subject if not available in new exam
                              if (!_availableSubjects.contains(
                                _selectedSubject,
                              )) {
                                _selectedSubject = _availableSubjects.first;
                              }
                            });
                            _loadTopics();
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),

                // ── SUBJECT filter ────────────────────────────────────────
                _FilterLabel(label: 'SUBJECT'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: _availableSubjects
                      .map(
                        (s) => _Chip(
                          label: s,
                          selected: _selectedSubject == s,
                          onTap: () {
                            setState(() => _selectedSubject = s);
                            _loadTopics();
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),

                // ── TOPICS filter ─────────────────────────────────────────
                Row(
                  children: [
                    _FilterLabel(
                      label: 'TOPICS',
                      subtitle: '(pick any — empty = all)',
                    ),
                    if (_loadingTopics) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: _muted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                if (_topics.length <= 1 && !_loadingTopics)
                  const Text(
                    'No topics available for this combination.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: _topics
                        .where((t) => t != 'Any')
                        .map(
                          (t) => _Chip(
                            label: t,
                            selected: _selectedTopic == t,
                            onTap: () => setState(
                              () => _selectedTopic = (_selectedTopic == t)
                                  ? 'Any'
                                  : t,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 28),

                // ── Find Opponent ─────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_findingOpponent || _creatingRoom)
                        ? null
                        : _findOpponent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _findingOpponent
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Finding Opponent…',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Find Opponent',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Create Room + Practice vs Bot ─────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _DarkButton(
                        icon: Icons.add_box_outlined,
                        label: _creatingRoom ? 'Waiting…' : 'Create Room',
                        onTap: (_creatingRoom || _findingOpponent)
                            ? null
                            : _createRoom,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DarkButton(
                        icon: Icons.smart_toy_outlined,
                        label: _loadingBotGame ? 'Loading…' : 'Practice vs Bot',
                        onTap: _loadingBotGame ? null : _practiceVsBot,
                      ),
                    ),
                  ],
                ),

                // ── Created room code display ─────────────────────────────
                if (_createdRoomCode != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.teal.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Share this code with your friend:',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _createdRoomCode!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: _createdRoomCode!),
                                );
                                _showSnack('Code copied!');
                              },
                              child: const Icon(
                                Icons.copy_rounded,
                                color: AppColors.teal,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppColors.teal,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Waiting for opponent to join…',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            _matchChannel?.unsubscribe();
                            if (_createdRoomCode != null) {
                              await _db
                                  .from('compete_matches')
                                  .delete()
                                  .eq('room_code', _createdRoomCode!)
                                  .eq('status', 'pending');
                            }
                            if (mounted) {
                              setState(() {
                                _creatingRoom = false;
                                _createdRoomCode = null;
                              });
                            }
                          },
                          child: const Text(
                            'Cancel Room',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Join Room ─────────────────────────────────────────────
                const Text(
                  'ROOM CODE',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _roomCodeCtrl,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
                        ),
                        decoration: InputDecoration(
                          hintText: 'ENTER CODE',
                          hintStyle: const TextStyle(
                            color: Color(0xFF475569),
                            letterSpacing: 2,
                          ),
                          filled: true,
                          fillColor: _card,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.teal,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _joiningRoom ? null : _joinRoom,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          disabledBackgroundColor: AppColors.teal.withValues(
                            alpha: 0.5,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _joiningRoom
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Join',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String icon, label, value;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterLabel extends StatelessWidget {
  final String label;
  final String? subtitle;
  const _FilterLabel({required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(width: 4),
        Text(
          subtitle!,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
        ),
      ],
    ],
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primary : _border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : _muted,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _DarkButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _DarkButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: onTap == null ? const Color(0xFF475569) : Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: onTap == null ? const Color(0xFF475569) : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'compete_models.dart';
import 'compete_question.dart';
import 'compete_lobby_widget.dart';
import 'compete_searching_widget.dart';
import 'compete_countdown_widget.dart';
import 'battle_game_screen.dart';
import 'compete_result_screen.dart';

const _kMatchKey = 'compete_active_match_id';

class CompeteScreenV2 extends ConsumerStatefulWidget {
  const CompeteScreenV2({super.key});

  @override
  ConsumerState<CompeteScreenV2> createState() => _CompeteScreenV2State();
}

class _CompeteScreenV2State extends ConsumerState<CompeteScreenV2>
    with WidgetsBindingObserver {
  final _db = Supabase.instance.client;

  CompetePhase _phase = CompetePhase.lobby;
  CompeteMatch? _match;
  List<CompeteQuestion> _questions = [];
  CompeteRating _rating = const CompeteRating();
  bool _busy = false;
  String? _joinError;

  // Searching state
  String? _searchingRoomCode;
  Timer? _pollTimer;
  RealtimeChannel? _waitChannel;

  // Bot queue entry for cancel
  String? _myQueueId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRating();
    _tryResumeMatch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    if (_waitChannel != null) _db.removeChannel(_waitChannel!);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tryResumeMatch();
  }

  String get _userId => _db.auth.currentUser?.id ?? '';
  String get _userName =>
      _db.auth.currentUser?.userMetadata?['full_name'] as String? ?? 'Student';

  // Fetches full_name + avatar_url for a user.
  // Priority: profiles.user_id → profiles.id → compete_queue.user_name → auth metadata
  Future<Map<String, String?>> _fetchProfile(String uid) async {
    if (uid.isEmpty) return {'name': null, 'avatar': null};
    String? name;
    String? avatar;

    // 1. Try profiles table by user_id
    try {
      var row = await _db
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('user_id', uid)
          .maybeSingle();
      // 2. Fallback: profiles.id = uid (some schemas use id as auth uid)
      row ??= await _db
          .from('profiles')
          .select('full_name, avatar_url')
          .eq('id', uid)
          .maybeSingle();
      if (row != null) {
        name = row['full_name'] as String?;
        avatar = row['avatar_url'] as String?;
      }
    } catch (_) {}

    // 3. Try compete_queue — captures name at the moment user queued up
    if (name == null || name.isEmpty) {
      try {
        final qRow = await _db
            .from('compete_queue')
            .select('user_name')
            .eq('user_id', uid)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        final qName = qRow?['user_name'] as String?;
        if (qName != null && qName.isNotEmpty) name = qName;
      } catch (_) {}
    }

    // 4. Try compete_match_answers — some web apps write user metadata there
    if (name == null || name.isEmpty) {
      try {
        final aRow = await _db
            .from('compete_match_answers')
            .select('user_name')
            .eq('user_id', uid)
            .limit(1)
            .maybeSingle();
        final aName = aRow?['user_name'] as String?;
        if (aName != null && aName.isNotEmpty) name = aName;
      } catch (_) {}
    }

    // 5. Last resort: read directly from auth.users via SECURITY DEFINER RPC
    if (name == null || name.isEmpty || avatar == null) {
      try {
        final nameResult = await _db.rpc('get_user_display_name', params: {'uid': uid});
        final rName = nameResult as String?;
        if (rName != null && rName.isNotEmpty && rName != 'Student') name = rName;
      } catch (_) {}
      if (avatar == null) {
        try {
          final avatarResult = await _db.rpc('get_user_avatar_url', params: {'uid': uid});
          final rAvatar = avatarResult as String?;
          if (rAvatar != null && rAvatar.isNotEmpty) avatar = rAvatar;
        } catch (_) {}
      }
    }

    return {
      'name': name?.isNotEmpty == true ? name : null,
      'avatar': avatar?.isNotEmpty == true ? avatar : null,
    };
  }


  // ── Rating ────────────────────────────────────────────────────────────────

  Future<void> _loadRating() async {
    if (_userId.isEmpty) return;
    try {
      final row = await _db
          .from('compete_ratings')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() => _rating = CompeteRating.fromJson(row));
      }
    } catch (_) {}
  }

  // ── Resume ────────────────────────────────────────────────────────────────

  Future<void> _tryResumeMatch() async {
    final prefs = await SharedPreferences.getInstance();
    final matchId = prefs.getString(_kMatchKey);
    if (matchId == null || !mounted) return;

    try {
      final row = await _db
          .from('compete_matches')
          .select()
          .eq('id', matchId)
          .maybeSingle();
      if (row == null) { await prefs.remove(_kMatchKey); return; }

      final match = CompeteMatch.fromJson(row);
      final isParticipant =
          match.player1Id == _userId || match.player2Id == _userId;
      if (!isParticipant) { await prefs.remove(_kMatchKey); return; }

      if (match.status == 'active' || match.status == 'pending') {
        final questions = await _fetchQuestionsByIds(match.questionIds);
        if (!mounted) return;
        setState(() {
          _match = match;
          _questions = questions;
          _phase = match.status == 'active'
              ? CompetePhase.match
              : CompetePhase.searching;
        });
      } else {
        await prefs.remove(_kMatchKey);
      }
    } catch (_) {}
  }

  Future<void> _persistMatch(String matchId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMatchKey, matchId);
  }

  Future<void> _clearPersistedMatch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMatchKey);
  }

  // ── Fetch questions ───────────────────────────────────────────────────────

  Future<List<CompeteQuestion>> _fetchQuestions(
      String subject, String topic,
      {String? classLevel, String? examType}) async {
    // Try with class/exam filters first; fall back to subject-only if columns missing
    if (classLevel != null || examType != null) {
      try {
        var query = _db
            .from('compete_questions')
            .select(
                'id, subject, topic, difficulty, question_text, options, correct_index, explanation')
            .eq('subject', subject)
            .eq('is_active', true);
        if (topic != 'Any' && topic.isNotEmpty) query = query.eq('topic', topic);
        if (classLevel != null && classLevel.isNotEmpty) {
          query = query.eq('class_level', classLevel);
        }
        if (examType != null && examType.isNotEmpty) {
          query = query.eq('exam_type', examType);
        }
        final data = await query;
        final all = (data as List)
            .map((r) => CompeteQuestion.fromJson(r as Map<String, dynamic>))
            .toList()
          ..shuffle(Random());
        if (all.isNotEmpty) return all.take(10).toList();
        // No results with filters — fall through to subject-only
      } catch (_) {
        // Columns don't exist yet — fall through to subject-only query
      }
    }

    // Subject-only fallback
    var query = _db
        .from('compete_questions')
        .select(
            'id, subject, topic, difficulty, question_text, options, correct_index, explanation')
        .eq('subject', subject)
        .eq('is_active', true);
    if (topic != 'Any' && topic.isNotEmpty) query = query.eq('topic', topic);
    final data = await query;
    final all = (data as List)
        .map((r) => CompeteQuestion.fromJson(r as Map<String, dynamic>))
        .toList()
      ..shuffle(Random());
    return all.take(10).toList();
  }

  Future<List<CompeteQuestion>> _fetchQuestionsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final data = await _db
        .from('compete_questions')
        .select(
            'id, subject, topic, difficulty, question_text, options, correct_index, explanation')
        .inFilter('id', ids);
    final list = (data as List)
        .map((r) => CompeteQuestion.fromJson(r as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
    return list;
  }

  // ── Lobby actions ─────────────────────────────────────────────────────────

  Future<void> _handleLobbyAction({
    required String action,
    required String subject,
    required String topic,
    required String classLevel,
    required String examType,
    String? roomCode,
  }) async {
    if (_busy) return;
    setState(() { _busy = true; _joinError = null; });

    try {
      switch (action) {
        case 'find':
          await _findOpponent(subject, topic, classLevel, examType);
        case 'bot':
          await _startBot(subject, topic, classLevel, examType);
        case 'create':
          await _createRoom(subject, topic, classLevel, examType);
        case 'join':
          await _joinRoom(roomCode!, subject, topic);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _showSnack('Error: $e');
      }
    }
  }

  Future<void> _findOpponent(
      String subject, String topic, String classLevel, String examType) async {
    try {
      final res = await _db.functions.invoke('compete-matchmake', body: {
        'action': 'find',
        'subject': subject,
        'topic': topic,
        'class_level': classLevel,
        'exam_type': examType,
      });
      final data = res.data as Map<String, dynamic>?;
      if (data?['status'] == 'matched') {
        await _onMatchFound(data!['match_id'] as String);
        return;
      }
    } catch (_) {}

    await _joinQueueAndWait(subject, topic, classLevel, examType);
  }

  Future<void> _joinQueueAndWait(
      String subject, String topic, String classLevel, String examType) async {
    // Check for waiting opponent with same class+exam+subject
    List<dynamic> waiting = [];
    try {
      waiting = await _db
          .from('compete_queue')
          .select()
          .eq('subject', subject)
          .eq('class_level', classLevel)
          .eq('exam_type', examType)
          .eq('status', 'waiting')
          .neq('user_id', _userId)
          .order('created_at')
          .limit(1);
    } catch (_) {
      // columns may not exist yet — fall back to subject-only filter
      try {
        waiting = await _db
            .from('compete_queue')
            .select()
            .eq('subject', subject)
            .eq('status', 'waiting')
            .neq('user_id', _userId)
            .order('created_at')
            .limit(1);
      } catch (_) {}
    }

    if (waiting.isNotEmpty) {
      await _matchDirectly(
          waiting.first, subject, topic, classLevel, examType);
      return;
    }

    // Join queue — try with new columns, fall back if they don't exist
    Map<String, dynamic> queueRow;
    try {
      queueRow = await _db.from('compete_queue').insert({
        'user_id': _userId,
        'user_name': _userName,
        'subject': subject,
        'topic': topic == 'Any' ? '' : topic,
        'class_level': classLevel,
        'exam_type': examType,
        'rating': _rating.rating,
        'status': 'waiting',
      }).select('id').single();
    } catch (_) {
      // new columns not yet in DB — insert without them
      queueRow = await _db.from('compete_queue').insert({
        'user_id': _userId,
        'user_name': _userName,
        'subject': subject,
        'topic': topic == 'Any' ? '' : topic,
        'rating': _rating.rating,
        'status': 'waiting',
      }).select('id').single();
    }
    final res = queueRow;
    _myQueueId = res['id'] as String;

    setState(() {
      _phase = CompetePhase.searching;
      _searchingRoomCode = null;
      _busy = false;
    });

    // Poll every 3s
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final res2 = await _db.functions.invoke('compete-matchmake', body: {
          'action': 'poll',
          'subject': subject,
          'topic': topic,
          'class_level': classLevel,
          'exam_type': examType,
        });
        final d = res2.data as Map<String, dynamic>?;
        if (d?['status'] == 'matched') {
          _pollTimer?.cancel();
          await _onMatchFound(d!['match_id'] as String);
        }
      } catch (_) {
        if (_myQueueId != null) {
          final row = await _db
              .from('compete_queue')
              .select('match_id, status')
              .eq('id', _myQueueId!)
              .maybeSingle();
          final mid = row?['match_id'] as String?;
          if (mid != null && mounted) {
            _pollTimer?.cancel();
            await _onMatchFound(mid);
          }
        }
      }
    });
  }

  Future<void> _matchDirectly(
      Map<String, dynamic> opponent,
      String subject, String topic,
      String classLevel, String examType) async {
    final oppQueueId = opponent['id'] as String;
    final oppId = opponent['user_id'] as String;
    final oppName = opponent['user_name'] as String? ?? 'Opponent';

    await _db
        .from('compete_queue')
        .update({'status': 'matched'})
        .eq('id', oppQueueId);

    final questions = await _fetchQuestions(subject, topic,
        classLevel: classLevel, examType: examType);
    final questionIds = questions.map((q) => q.id).toList();
    final countdownUntil =
        DateTime.now().toUtc().add(const Duration(seconds: 6));

    final res = await _safeMatchInsert({
      'player1_id': _userId,
      'player1_name': _userName,
      'player2_id': oppId,
      'player2_name': oppName,
      'subject': subject,
      'topic': topic == 'Any' ? '' : topic,
      'class_level': classLevel,
      'exam_type': examType,
      'question_ids': questionIds,
      'total_questions': questions.length,
      'status': 'active',
      'is_bot': false,
      'is_private': false,
      'player1_rating_before': _rating.rating,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'countdown_until': countdownUntil.toIso8601String(),
      'current_question_started_at': countdownUntil.toIso8601String(),
    });

    final matchId = res['id'] as String;
    await _db
        .from('compete_queue')
        .update({'match_id': matchId, 'status': 'matched'})
        .eq('id', oppQueueId);

    await _onMatchFound(matchId, preloadedQuestions: questions);
  }

  Future<void> _startBot(
      String subject, String topic, String classLevel, String examType) async {
    try {
      final res = await _db.functions.invoke('compete-matchmake', body: {
        'action': 'bot',
        'subject': subject,
        'topic': topic,
        'class_level': classLevel,
        'exam_type': examType,
      });
      final data = res.data as Map<String, dynamic>?;
      if (data?['match_id'] != null) {
        await _onMatchFound(data!['match_id'] as String);
        return;
      }
    } catch (_) {}

    // Local bot match
    final questions = await _fetchQuestions(subject, topic,
        classLevel: classLevel, examType: examType);
    if (questions.isEmpty) {
      if (mounted) {
        setState(() => _busy = false);
        _showSnack('No questions available for this topic.');
      }
      return;
    }
    final questionIds = questions.map((q) => q.id).toList();
    final now = DateTime.now().toUtc();
    final countdownUntil = now.add(const Duration(seconds: 6));

    CompeteMatch botMatch;
    try {
      final res = await _safeMatchInsert({
        'player1_id': _userId,
        'player1_name': _userName,
        'player2_id': kBotUserId,
        'player2_name': 'AI Opponent',
        'subject': subject,
        'topic': topic == 'Any' ? '' : topic,
        'class_level': classLevel,
        'exam_type': examType,
        'question_ids': questionIds,
        'total_questions': questions.length,
        'status': 'active',
        'is_bot': true,
        'is_private': false,
        'player1_rating_before': _rating.rating,
        'started_at': now.toIso8601String(),
        'countdown_until': countdownUntil.toIso8601String(),
        'current_question_started_at': countdownUntil.toIso8601String(),
      }, returnAll: true);
      botMatch = CompeteMatch.fromJson(res);
    } catch (_) {
      // Fully offline fallback
      botMatch = CompeteMatch(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        player1Id: _userId,
        player1Name: _userName,
        player2Id: kBotUserId,
        player2Name: 'AI Opponent',
        subject: subject,
        topic: topic == 'Any' ? '' : topic,
        questionIds: questionIds,
        totalQuestions: questions.length,
        status: 'active',
        isBot: true,
        countdownUntil: countdownUntil.toLocal(),
        currentQuestionStartedAt: countdownUntil.toLocal(),
      );
    }

    if (!mounted) return;
    setState(() {
      _match = botMatch;
      _questions = questions;
      _phase = CompetePhase.countdown;
      _busy = false;
    });
  }

  Future<void> _createRoom(
      String subject, String topic, String classLevel, String examType) async {
    String? roomCode;
    String? matchId;

    try {
      final res = await _db.functions.invoke('compete-create-room', body: {
        'subject': subject,
        'topic': topic,
        'class_level': classLevel,
        'exam_type': examType,
      });
      final data = res.data as Map<String, dynamic>?;
      matchId = data?['match_id'] as String?;
      roomCode = data?['room_code'] as String?;
    } catch (_) {}

    if (roomCode == null || matchId == null) {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final rand = Random();
      roomCode = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
      final questions = await _fetchQuestions(subject, topic,
          classLevel: classLevel, examType: examType);
      if (questions.isEmpty) {
        if (mounted) {
          setState(() => _busy = false);
          _showSnack('No questions available for this topic.');
        }
        return;
      }
      final res = await _safeMatchInsert({
        'player1_id': _userId,
        'player1_name': _userName,
        'subject': subject,
        'topic': topic == 'Any' ? '' : topic,
        'class_level': classLevel,
        'exam_type': examType,
        'question_ids': questions.map((q) => q.id).toList(),
        'total_questions': questions.length,
        'status': 'pending',
        'is_private': true,
        'is_bot': false,
        'room_code': roomCode,
        'player1_rating_before': _rating.rating,
      });
      matchId = res['id'] as String;
    }

    await _persistMatch(matchId);

    _waitChannel = _db
        .channel('room_wait_$matchId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'compete_matches',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: matchId,
        ),
        callback: (payload) async {
          final row = payload.newRecord;
          final p2 = row['player2_id'] as String?;
          final status = row['status'] as String?;
          if (p2 != null && p2.isNotEmpty && status == 'active' && mounted) {
            if (_waitChannel != null) _db.removeChannel(_waitChannel!);
            await _onMatchFound(matchId!);
          }
        },
      )
      ..subscribe();

    if (mounted) {
      setState(() {
        _phase = CompetePhase.searching;
        _searchingRoomCode = roomCode;
        _busy = false;
      });
    }
  }

  Future<void> _joinRoom(
      String roomCode, String subject, String topic) async {
    try {
      final res = await _db.functions.invoke('compete-join-room',
          body: {'room_code': roomCode});
      final data = res.data as Map<String, dynamic>?;
      final matchId = data?['match_id'] as String?;
      if (matchId != null) {
        await _onMatchFound(matchId);
        return;
      }
    } catch (_) {}

    // Direct join — class/exam come from the existing match record
    final rows = await _db
        .from('compete_matches')
        .select()
        .eq('room_code', roomCode)
        .eq('status', 'pending')
        .limit(1);

    if (rows.isEmpty) {
      if (mounted) {
        setState(() {
          _busy = false;
          _joinError = 'Room not found or already started.';
        });
      }
      return;
    }

    final match = rows.first;
    final matchId = match['id'] as String;

    await _db.from('compete_matches').update({
      'player2_id': _userId,
      'player2_name': _userName,
      'player2_rating_before': _rating.rating,
      'status': 'active',
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'countdown_until':
          DateTime.now().toUtc().add(const Duration(seconds: 6)).toIso8601String(),
    }).eq('id', matchId);

    await _onMatchFound(matchId);
  }

  Future<void> _onMatchFound(String matchId,
      {List<CompeteQuestion>? preloadedQuestions}) async {
    try {
      final row = await _db
          .from('compete_matches')
          .select()
          .eq('id', matchId)
          .single();
      CompeteMatch match = CompeteMatch.fromJson(row);

      final imP1 = match.player1Id == _userId;
      final p2Id = match.player2Id ?? '';
      final isRealP2 = p2Id.isNotEmpty && p2Id != kBotUserId;

      // Patch my name into the match if the DB row is missing it — this lets
      // the opponent see my name via Realtime even if the web app didn't store it.
      final myNameInDb = imP1 ? match.player1Name : match.player2Name;
      if (myNameInDb == null || myNameInDb.isEmpty) {
        try {
          final col = imP1 ? 'player1_name' : 'player2_name';
          await _db.from('compete_matches').update({col: _userName}).eq('id', matchId);
        } catch (_) {}
      }

      // Fetch avatars in parallel; name lookup is secondary (match row has names).
      final oppId = imP1 ? p2Id : match.player1Id;
      final results = await Future.wait([
        _fetchProfile(_userId),          // my profile for avatar
        isRealP2
            ? _fetchProfile(oppId)       // opponent profile for avatar + name fallback
            : Future.value(<String, String?>{'name': null, 'avatar': null}),
      ]);
      final myProfile = results[0];
      final oppProfile = results[1];

      // Build final names: prefer match row name → profile table → 'Student'/'Opponent'
      final myNameFinal = myProfile['name']?.isNotEmpty == true
          ? myProfile['name']!
          : (myNameInDb?.isNotEmpty == true ? myNameInDb! : _userName);
      final oppNameInDb = imP1 ? match.player2Name : match.player1Name;
      final oppNameFinal = match.isBot
          ? 'AI Opponent'
          : (oppProfile['name']?.isNotEmpty == true
              ? oppProfile['name']!
              : (oppNameInDb?.isNotEmpty == true ? oppNameInDb! : 'Opponent'));

      match = match.copyWithProfiles(
        player1Name: imP1 ? myNameFinal : oppNameFinal,
        player1Avatar: imP1 ? myProfile['avatar'] : oppProfile['avatar'],
        player2Name: imP1 ? oppNameFinal : myNameFinal,
        player2Avatar: imP1 ? oppProfile['avatar'] : myProfile['avatar'],
      );

      final questions = preloadedQuestions ??
          await _fetchQuestionsByIds(match.questionIds);

      await _persistMatch(matchId);

      if (!mounted) return;
      setState(() {
        _match = match;
        _questions = questions;
        _phase = CompetePhase.countdown;
        _busy = false;
        _myQueueId = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _showSnack('Failed to load match: $e');
      }
    }
  }

  // ── Safe insert helpers (gracefully drop unknown columns) ────────────────

  /// Inserts into compete_matches. If the DB rejects class_level/exam_type
  /// (columns not yet migrated), retries without them.
  Future<Map<String, dynamic>> _safeMatchInsert(
      Map<String, dynamic> data, {bool returnAll = false}) async {
    try {
      final q = _db.from('compete_matches').insert(data);
      return returnAll ? await q.select().single() : await q.select('id').single();
    } catch (_) {
      final fallback = Map<String, dynamic>.from(data)
        ..remove('class_level')
        ..remove('exam_type');
      final q = _db.from('compete_matches').insert(fallback);
      return returnAll ? await q.select().single() : await q.select('id').single();
    }
  }

  // ── Cancel searching ──────────────────────────────────────────────────────

  Future<void> _cancelSearching() async {
    _pollTimer?.cancel();
    if (_waitChannel != null) {
      _db.removeChannel(_waitChannel!);
      _waitChannel = null;
    }

    try {
      if (_searchingRoomCode != null && _match != null) {
        await _db
            .from('compete_matches')
            .delete()
            .eq('id', _match!.id)
            .eq('status', 'pending');
      } else if (_myQueueId != null) {
        await _db
            .from('compete_queue')
            .delete()
            .eq('id', _myQueueId!);
        _myQueueId = null;
      } else {
        await _db.functions.invoke('compete-matchmake', body: {'action': 'cancel'});
      }
    } catch (_) {}

    await _clearPersistedMatch();
    if (mounted) {
      setState(() {
        _phase = CompetePhase.lobby;
        _match = null;
        _searchingRoomCode = null;
        _busy = false;
      });
    }
  }

  // ── Result ────────────────────────────────────────────────────────────────

  void _onMatchFinished(CompeteMatch match, List<CompeteAnswer> myAnswers, List<CompeteAnswer> passedOppAnswers) {
    if (!mounted) return;
    _clearPersistedMatch();
    setState(() {
      _match = match;
      _phase = CompetePhase.result;
    });

    _pushResultScreen(match, myAnswers, passedOppAnswers);
  }

  Future<void> _pushResultScreen(
      CompeteMatch match, List<CompeteAnswer> myAnswers, List<CompeteAnswer> passedOppAnswers) async {
    List<CompeteAnswer> oppAnswers = passedOppAnswers;
    // For P2P matches, fetch opponent answers from DB if not already provided
    if (oppAnswers.isEmpty) {
      try {
        final oppId = match.player1Id == _userId ? match.player2Id : match.player1Id;
        if (oppId != null && oppId.isNotEmpty && oppId != kBotUserId) {
          final rows = await _db
              .from('compete_match_answers')
              .select()
              .eq('match_id', match.id)
              .eq('user_id', oppId);
          oppAnswers = (rows as List)
              .map((r) => CompeteAnswer.fromJson(r as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CompeteResultScreen(
        match: match,
        myAnswers: myAnswers,
        oppAnswers: oppAnswers,
        questions: _questions,
        userId: _userId,
        onPlayAgain: () {
          Navigator.of(context).pop();
          setState(() {
            _phase = CompetePhase.lobby;
            _match = null;
            _questions = [];
          });
          _loadRating();
        },
        onLobby: () {
          Navigator.of(context).pop();
          setState(() {
            _phase = CompetePhase.lobby;
            _match = null;
            _questions = [];
          });
          _loadRating();
        },
      ),
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                    .animate(anim),
            child: child,
          ),
        ),
        child: _buildPhase(),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case CompetePhase.lobby:
        return CompeteLobbyWidget(
          key: const ValueKey('lobby'),
          rating: _rating,
          busy: _busy,
          joinError: _joinError,
          onAction: ({
            required action,
            required subject,
            required topic,
            required classLevel,
            required examType,
            roomCode,
          }) =>
              _handleLobbyAction(
            action: action,
            subject: subject,
            topic: topic,
            classLevel: classLevel,
            examType: examType,
            roomCode: roomCode,
          ),
        );

      case CompetePhase.searching:
        return CompeteSearchingWidget(
          key: const ValueKey('searching'),
          roomCode: _searchingRoomCode,
          onCancel: _cancelSearching,
        );

      case CompetePhase.countdown:
        if (_match == null) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }
        return CompeteCountdownWidget(
          key: ValueKey('countdown_${_match!.id}'),
          match: _match!,
          userId: _userId,
          onCountdownDone: () {
            if (mounted) setState(() => _phase = CompetePhase.match);
          },
        );

      case CompetePhase.match:
        if (_match == null || _questions.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }
        return BattleGameScreen(
          key: ValueKey('match_${_match!.id}'),
          match: _match!,
          questions: _questions,
          userId: _userId,
          onFinished: _onMatchFinished,
        );

      case CompetePhase.result:
        // Result is shown as a pushed route; show lobby behind it
        return CompeteLobbyWidget(
          key: const ValueKey('lobby_behind_result'),
          rating: _rating,
          busy: false,
          onAction: ({
            required action,
            required subject,
            required topic,
            required classLevel,
            required examType,
            roomCode,
          }) =>
              _handleLobbyAction(
            action: action,
            subject: subject,
            topic: topic,
            classLevel: classLevel,
            examType: examType,
            roomCode: roomCode,
          ),
        );
    }
  }
}

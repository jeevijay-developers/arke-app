// Data models for the compete feature.

const String kBotUserId = '00000000-0000-0000-0000-000000000000';

const Map<String, List<String>> kSubjectTopics = {
  'Physics': ['Any', 'Kinematics', 'Laws of Motion'],
  'Chemistry': ['Any', 'Atomic Structure', 'Periodic Table', 'Mole Concept'],
  'Math': ['Any', 'Algebra', 'Trigonometry', 'Calculus'],
  'Biology': ['Any', 'Cell', 'Human Physiology'],
};

const List<String> kSubjects = ['Physics', 'Chemistry', 'Math', 'Biology'];

enum CompetePhase { lobby, searching, countdown, match, result }

class CompeteMatch {
  final String id;
  final String player1Id;
  final String? player2Id;
  final String? player1Name;
  final String? player2Name;
  final String? player1Avatar;
  final String? player2Avatar;
  final int player1Score;
  final int player2Score;
  final int? player1RatingBefore;
  final int? player2RatingBefore;
  final int? player1RatingAfter;
  final int? player2RatingAfter;
  final String subject;
  final String topic;
  final List<String> questionIds;
  final int currentQuestionIndex;
  final int totalQuestions;
  final String status; // "pending" | "active" | "finished"
  final bool isBot;
  final bool isPrivate;
  final String? roomCode;
  final String? winnerId;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? countdownUntil;
  final DateTime? currentQuestionStartedAt;

  const CompeteMatch({
    required this.id,
    required this.player1Id,
    this.player2Id,
    this.player1Name,
    this.player2Name,
    this.player1Avatar,
    this.player2Avatar,
    this.player1Score = 0,
    this.player2Score = 0,
    this.player1RatingBefore,
    this.player2RatingBefore,
    this.player1RatingAfter,
    this.player2RatingAfter,
    required this.subject,
    required this.topic,
    required this.questionIds,
    this.currentQuestionIndex = 0,
    this.totalQuestions = 10,
    required this.status,
    this.isBot = false,
    this.isPrivate = false,
    this.roomCode,
    this.winnerId,
    this.startedAt,
    this.finishedAt,
    this.countdownUntil,
    this.currentQuestionStartedAt,
  });

  factory CompeteMatch.fromJson(Map<String, dynamic> j) => CompeteMatch(
        id: j['id'] as String,
        player1Id: j['player1_id'] as String? ?? '',
        player2Id: j['player2_id'] as String?,
        player1Name: j['player1_name'] as String?,
        player2Name: j['player2_name'] as String?,
        player1Avatar: j['player1_avatar'] as String?,
        player2Avatar: j['player2_avatar'] as String?,
        player1Score: (j['player1_score'] as num?)?.toInt() ?? 0,
        player2Score: (j['player2_score'] as num?)?.toInt() ?? 0,
        player1RatingBefore: (j['player1_rating_before'] as num?)?.toInt(),
        player2RatingBefore: (j['player2_rating_before'] as num?)?.toInt(),
        player1RatingAfter: (j['player1_rating_after'] as num?)?.toInt(),
        player2RatingAfter: (j['player2_rating_after'] as num?)?.toInt(),
        subject: j['subject'] as String? ?? '',
        topic: j['topic'] as String? ?? '',
        questionIds: _toStringList(j['question_ids']),
        currentQuestionIndex: (j['current_question_index'] as num?)?.toInt() ?? 0,
        totalQuestions: (j['total_questions'] as num?)?.toInt() ?? 10,
        status: j['status'] as String? ?? 'pending',
        isBot: j['is_bot'] as bool? ?? false,
        isPrivate: j['is_private'] as bool? ?? false,
        roomCode: j['room_code'] as String?,
        winnerId: j['winner_id'] as String?,
        startedAt: _parseDate(j['started_at']),
        finishedAt: _parseDate(j['finished_at']),
        countdownUntil: _parseDate(j['countdown_until']),
        currentQuestionStartedAt: _parseDate(j['current_question_started_at']),
      );

  static List<String> _toStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }

  CompeteMatch copyWith({
    int? player1Score,
    int? player2Score,
    int? player1RatingAfter,
    int? player2RatingAfter,
    int? currentQuestionIndex,
    String? status,
    String? winnerId,
    DateTime? currentQuestionStartedAt,
    DateTime? countdownUntil,
  }) =>
      CompeteMatch(
        id: id,
        player1Id: player1Id,
        player2Id: player2Id,
        player1Name: player1Name,
        player2Name: player2Name,
        player1Avatar: player1Avatar,
        player2Avatar: player2Avatar,
        player1Score: player1Score ?? this.player1Score,
        player2Score: player2Score ?? this.player2Score,
        player1RatingBefore: player1RatingBefore,
        player2RatingBefore: player2RatingBefore,
        player1RatingAfter: player1RatingAfter ?? this.player1RatingAfter,
        player2RatingAfter: player2RatingAfter ?? this.player2RatingAfter,
        subject: subject,
        topic: topic,
        questionIds: questionIds,
        currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
        totalQuestions: totalQuestions,
        status: status ?? this.status,
        isBot: isBot,
        isPrivate: isPrivate,
        roomCode: roomCode,
        winnerId: winnerId ?? this.winnerId,
        startedAt: startedAt,
        finishedAt: finishedAt,
        countdownUntil: countdownUntil ?? this.countdownUntil,
        currentQuestionStartedAt: currentQuestionStartedAt ?? this.currentQuestionStartedAt,
      );

  CompeteMatch copyWithProfiles({
    String? player1Name,
    String? player1Avatar,
    String? player2Name,
    String? player2Avatar,
  }) =>
      CompeteMatch(
        id: id,
        player1Id: player1Id,
        player2Id: player2Id,
        player1Name: player1Name ?? this.player1Name,
        player2Name: player2Name ?? this.player2Name,
        player1Avatar: player1Avatar ?? this.player1Avatar,
        player2Avatar: player2Avatar ?? this.player2Avatar,
        player1Score: player1Score,
        player2Score: player2Score,
        player1RatingBefore: player1RatingBefore,
        player2RatingBefore: player2RatingBefore,
        player1RatingAfter: player1RatingAfter,
        player2RatingAfter: player2RatingAfter,
        subject: subject,
        topic: topic,
        questionIds: questionIds,
        currentQuestionIndex: currentQuestionIndex,
        totalQuestions: totalQuestions,
        status: status,
        isBot: isBot,
        isPrivate: isPrivate,
        roomCode: roomCode,
        winnerId: winnerId,
        startedAt: startedAt,
        finishedAt: finishedAt,
        countdownUntil: countdownUntil,
        currentQuestionStartedAt: currentQuestionStartedAt,
      );
}

class CompeteAnswer {
  final String matchId;
  final String userId;
  final int questionIndex;
  final int? selectedIndex;
  final bool isCorrect;
  final int points;
  final int timeTakenMs;

  const CompeteAnswer({
    required this.matchId,
    required this.userId,
    required this.questionIndex,
    this.selectedIndex,
    required this.isCorrect,
    required this.points,
    required this.timeTakenMs,
  });

  factory CompeteAnswer.fromJson(Map<String, dynamic> j) => CompeteAnswer(
        matchId: j['match_id'] as String? ?? '',
        userId: j['user_id'] as String? ?? '',
        questionIndex: (j['question_index'] as num?)?.toInt() ?? 0,
        selectedIndex: (j['selected_index'] as num?)?.toInt(),
        isCorrect: j['is_correct'] as bool? ?? false,
        points: (j['points'] as num?)?.toInt() ?? 0,
        timeTakenMs: (j['time_taken_ms'] as num?)?.toInt() ?? 0,
      );
}

class CompeteRating {
  final int rating;
  final int wins;
  final int losses;
  final int draws;
  final int currentStreak;
  final int bestStreak;

  const CompeteRating({
    this.rating = 1000,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
  });

  factory CompeteRating.fromJson(Map<String, dynamic> j) => CompeteRating(
        rating: (j['rating'] as num?)?.toInt() ?? 1000,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        losses: (j['losses'] as num?)?.toInt() ?? 0,
        draws: (j['draws'] as num?)?.toInt() ?? 0,
        currentStreak: (j['current_streak'] as num?)?.toInt() ?? 0,
        bestStreak: (j['best_streak'] as num?)?.toInt() ?? 0,
      );
}

// ELO delta calculation for display
int calcEloDelta({
  required int myRating,
  required int opponentRating,
  required bool won,
  required bool draw,
}) {
  final score = won ? 1.0 : draw ? 0.5 : 0.0;
  final expected = 1.0 / (1.0 + _pow10((opponentRating - myRating) / 400.0));
  return (32 * (score - expected)).round();
}

double _pow10(double x) => _exp(x * 2.302585092994046);
double _exp(double x) {
  double result = 1.0;
  double term = 1.0;
  for (int i = 1; i <= 20; i++) {
    term *= x / i;
    result += term;
  }
  return result;
}

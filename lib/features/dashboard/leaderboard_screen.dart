import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────
// COLOR CONSTANTS
// ─────────────────────────────────────────────
abstract class _C {
  static const bg         = Color(0xFF0A0A0F);
  static const primary    = Color(0xFFF97316);
  static const accent     = Color(0xFFFF8C38);
  static const primaryDk  = Color(0xFFE05A00);
  static const gold       = Color(0xFFF59E0B);
  static const white10    = Color(0x1AFFFFFF);
  static const white24    = Color(0x3DFFFFFF);
  static const white54    = Color(0x8AFFFFFF);
}

// ─────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────
class _Rating {
  final String userId;
  final int rating, wins, losses, draws, currentStreak, bestStreak;
  final String targetExam;
  final DateTime updatedAt;

  const _Rating({
    required this.userId,
    required this.rating,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.currentStreak,
    required this.bestStreak,
    required this.targetExam,
    required this.updatedAt,
  });

  factory _Rating.fromJson(Map<String, dynamic> j) => _Rating(
        userId: j['user_id'] as String? ?? '',
        rating: (j['rating'] as num?)?.toInt() ?? 1000,
        wins: (j['wins'] as num?)?.toInt() ?? 0,
        losses: (j['losses'] as num?)?.toInt() ?? 0,
        draws: (j['draws'] as num?)?.toInt() ?? 0,
        currentStreak: (j['current_streak'] as num?)?.toInt() ?? 0,
        bestStreak: (j['best_streak'] as num?)?.toInt() ?? 0,
        targetExam: j['target_exam'] as String? ?? '',
        updatedAt: _parseDate(j['updated_at']),
      );

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    final s = v.toString();
    return DateTime.tryParse(s)?.toLocal() ??
        DateTime.tryParse('${s}Z')?.toLocal() ??
        DateTime.now();
  }
}

class _Row {
  final String userId;
  final int rating, wins, losses, draws, currentStreak, bestStreak;
  final String targetExam;
  final DateTime updatedAt;
  final int rank, matches, accuracy;
  final String name, initials;
  final bool isYou;
  final String? schoolId;

  const _Row({
    required this.userId,
    required this.rating,
    required this.wins,
    required this.losses,
    required this.draws,
    required this.currentStreak,
    required this.bestStreak,
    required this.targetExam,
    required this.updatedAt,
    required this.rank,
    required this.matches,
    required this.accuracy,
    required this.name,
    required this.initials,
    required this.isYou,
    required this.schoolId,
  });
}

String _initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

int _calcAccuracy(int wins, int losses, int draws) {
  final m = wins + losses + draws;
  if (m == 0) return 0;
  return ((wins / m) * 100).round();
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  late final AnimationController _podiumAnim;
  late RealtimeChannel _channel;

  // raw data
  List<_Rating> _ratings = [];
  Map<String, String> _nameMap = {};
  Map<String, String?> _schoolMap = {};
  String? _mySchoolId;
  String? _mySchoolName;
  List<String> _availableExams = [];

  // filters
  String _scopeFilter = 'global';
  String _examFilter  = 'all';
  String _rangeFilter = 'all';

  bool _loading = true;
  bool _reloading = false;

  String get _userId => _db.auth.currentUser?.id ?? '';

  // ── computed ──────────────────────────────
  List<_Row> get _rows {
    final now = DateTime.now().millisecondsSinceEpoch;
    final sinceMs = _rangeFilter == 'all'
        ? 0
        : now - int.parse(_rangeFilter) * 24 * 60 * 60 * 1000;

    final filtered = _ratings.where((r) {
      if (_examFilter != 'all' && r.targetExam != _examFilter) return false;
      if (sinceMs > 0 && r.updatedAt.millisecondsSinceEpoch < sinceMs) return false;
      if (_scopeFilter == 'school') {
        if (_mySchoolId == null) return false;
        if (_schoolMap[r.userId] != _mySchoolId) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));

    return filtered.asMap().entries.map((e) {
      final i = e.key;
      final r = e.value;
      final name = _nameMap[r.userId] ?? 'Player';
      final m = r.wins + r.losses + r.draws;
      return _Row(
        userId: r.userId,
        rating: r.rating,
        wins: r.wins,
        losses: r.losses,
        draws: r.draws,
        currentStreak: r.currentStreak,
        bestStreak: r.bestStreak,
        targetExam: r.targetExam,
        updatedAt: r.updatedAt,
        rank: i + 1,
        matches: m,
        accuracy: _calcAccuracy(r.wins, r.losses, r.draws),
        name: name,
        initials: _initialsOf(name),
        isYou: r.userId == _userId,
        schoolId: _schoolMap[r.userId],
      );
    }).toList();
  }

  List<_Row> get _topThree => _rows.take(3).toList();
  List<_Row> get _rest     => _rows.skip(3).toList();
  _Row?      get _yourRow  => _rows.firstWhereOrNull((r) => r.isYou);

  @override
  void initState() {
    super.initState();
    _podiumAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadData();
    _channel = _db
        .channel('leaderboard-ratings')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'compete_ratings',
          callback: (_) {
            if (!_reloading) _loadData(silent: true);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _podiumAnim.dispose();
    _db.removeChannel(_channel);
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    setState(() {
      if (!silent) _loading = true;
      _reloading = true;
    });

    try {
      // Step 1 – ratings
      final ratingsData = await _db
          .from('compete_ratings')
          .select(
              'user_id, rating, wins, losses, draws, current_streak, best_streak, target_exam, updated_at')
          .order('rating', ascending: false)
          .limit(200);

      final ratings = (ratingsData as List)
          .map((r) => _Rating.fromJson(r as Map<String, dynamic>))
          .toList();

      final ids = ratings.map((r) => r.userId).toSet().toList();

      final exams = ratings
          .map((r) => r.targetExam)
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

      if (ids.isEmpty) {
        if (mounted) {
          setState(() {
            _ratings = [];
            _availableExams = exams;
            _loading = false;
            _reloading = false;
          });
        }
        return;
      }

      // Step 2 – name map from matches
      final matchesData = await _db
          .from('compete_matches')
          .select('player1_id, player1_name, player2_id, player2_name')
          .or('player1_id.in.(${ids.join(",")}),player2_id.in.(${ids.join(",")})')
          .order('created_at', ascending: false)
          .limit(500);

      final Map<String, String> nameMap = {};
      for (final m in (matchesData as List)) {
        final mm = m as Map<String, dynamic>;
        final p1id = mm['player1_id'] as String?;
        final p1n  = mm['player1_name'] as String?;
        final p2id = mm['player2_id'] as String?;
        final p2n  = mm['player2_name'] as String?;
        if (p1id != null && p1n != null) nameMap.putIfAbsent(p1id, () => p1n);
        if (p2id != null && p2n != null) nameMap.putIfAbsent(p2id, () => p2n);
      }

      // Step 3 – profiles for school + fallback name
      final profilesData = await _db
          .from('profiles')
          .select('user_id, full_name, school_id')
          .inFilter('user_id', ids);

      final Map<String, String?> schoolMap = {};
      for (final p in (profilesData as List)) {
        final pp = p as Map<String, dynamic>;
        final uid = pp['user_id'] as String?;
        if (uid == null) continue;
        schoolMap[uid] = pp['school_id'] as String?;
        nameMap.putIfAbsent(uid, () => pp['full_name'] as String? ?? 'Player');
      }

      // Step 4 – my profile & school name
      String? mySchoolId;
      String? mySchoolName;
      if (_userId.isNotEmpty) {
        final myProfile = await _db
            .from('profiles')
            .select('full_name, school_id')
            .eq('user_id', _userId)
            .maybeSingle();
        mySchoolId = myProfile?['school_id'] as String?;
        // Always use the latest name from profiles for the current user,
        // overriding any stale name stored in compete_matches.
        final myName = myProfile?['full_name'] as String?;
        if (myName != null && myName.isNotEmpty) {
          nameMap[_userId] = myName;
        }
        if (mySchoolId != null) {
          final school = await _db
              .from('schools')
              .select('name')
              .eq('id', mySchoolId)
              .maybeSingle();
          mySchoolName = school?['name'] as String?;
        }
      }

      if (!mounted) return;
      setState(() {
        _ratings       = ratings;
        _nameMap       = nameMap;
        _schoolMap     = schoolMap;
        _availableExams = exams;
        _mySchoolId    = mySchoolId;
        _mySchoolName  = mySchoolName;
        if (mySchoolId == null && _scopeFilter == 'school') {
          _scopeFilter = 'global';
        }
        _loading    = false;
        _reloading  = false;
      });

      _podiumAnim.forward(from: 0);
    } catch (e) {
      if (mounted) {
        setState(() { _loading = false; _reloading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load leaderboard')),
        );
      }
    }
  }

  // ── build ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final yourRow = _yourRow;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _Header(
                  scopeFilter: _scopeFilter,
                  mySchoolName: _mySchoolName,
                  onBack: () => Navigator.of(context).maybePop(),
                  onRefresh: () => _loadData(),
                )),
                SliverToBoxAdapter(child: _FilterRow(
                  scopeFilter: _scopeFilter,
                  examFilter: _examFilter,
                  rangeFilter: _rangeFilter,
                  availableExams: _availableExams,
                  mySchoolId: _mySchoolId,
                  onScope: (v) => setState(() => _scopeFilter = v),
                  onExam:  (v) => setState(() => _examFilter = v),
                  onRange: (v) => setState(() => _rangeFilter = v),
                )),
                SliverToBoxAdapter(child: _PodiumSection(
                  loading: _loading,
                  topThree: _topThree,
                  anim: _podiumAnim,
                  scopeFilter: _scopeFilter,
                )),
                SliverToBoxAdapter(child: _TableSection(
                  loading: _loading,
                  rest: _rest,
                  scopeFilter: _scopeFilter,
                )),
                // Bottom padding so sticky bar doesn't cover last row
                SliverToBoxAdapter(child: SizedBox(
                  height: yourRow != null ? 80 + bottomPad : 24,
                )),
              ],
            ),

            // Sticky position bar
            if (yourRow != null)
              Positioned(
                bottom: 72 + bottomPad,   // 72 = approx bottom nav height
                left: 16,
                right: 16,
                child: _YourPositionBar(
                  row: yourRow,
                  scopeFilter: _scopeFilter,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String scopeFilter;
  final String? mySchoolName;
  final VoidCallback onBack, onRefresh;

  const _Header({
    required this.scopeFilter,
    required this.mySchoolName,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = scopeFilter == 'school' && mySchoolName != null
        ? 'Ranking within $mySchoolName'
        : 'Live rankings from Compete matches';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _C.white10,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.white10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: _C.accent, size: 22),
                  const SizedBox(width: 6),
                  const Text(
                    'Leaderboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: _C.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRefresh,
            child: const Icon(Icons.refresh_rounded,
                color: _C.white54, size: 22),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FILTER ROW
// ─────────────────────────────────────────────
class _FilterRow extends StatelessWidget {
  final String scopeFilter, examFilter, rangeFilter;
  final List<String> availableExams;
  final String? mySchoolId;
  final void Function(String) onScope, onExam, onRange;

  const _FilterRow({
    required this.scopeFilter,
    required this.examFilter,
    required this.rangeFilter,
    required this.availableExams,
    required this.mySchoolId,
    required this.onScope,
    required this.onExam,
    required this.onRange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          // Scope
          Expanded(child: _Dropdown<String>(
            value: scopeFilter,
            items: [
              _DropItem(
                value: 'global',
                label: 'Global',
                icon: Icons.public_rounded,
              ),
              _DropItem(
                value: 'school',
                label: 'My School',
                icon: Icons.school_rounded,
                enabled: mySchoolId != null,
              ),
            ],
            onChanged: (v) { if (v != null) onScope(v); },
          )),
          const SizedBox(width: 8),
          // Exam
          Expanded(child: _Dropdown<String>(
            value: examFilter,
            items: [
              const _DropItem(value: 'all', label: 'All Exams',
                  icon: Icons.layers_rounded),
              ...availableExams.map((e) => _DropItem(
                    value: e,
                    label: e,
                    icon: Icons.bookmark_rounded,
                  )),
            ],
            onChanged: (v) { if (v != null) onExam(v); },
          )),
          const SizedBox(width: 8),
          // Time range
          Expanded(child: _Dropdown<String>(
            value: rangeFilter,
            items: const [
              _DropItem(value: 'all', label: 'All Time',
                  icon: Icons.history_rounded),
              _DropItem(value: '30', label: 'Monthly',
                  icon: Icons.calendar_month_rounded),
              _DropItem(value: '7',  label: 'Weekly',
                  icon: Icons.date_range_rounded),
            ],
            onChanged: (v) { if (v != null) onRange(v); },
          )),
        ],
      ),
    );
  }
}

class _DropItem {
  final String value, label;
  final IconData icon;
  final bool enabled;
  const _DropItem({
    required this.value,
    required this.label,
    required this.icon,
    this.enabled = true,
  });
}

class _Dropdown<T> extends StatelessWidget {
  final T value;
  final List<_DropItem> items;
  final void Function(T?) onChanged;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _C.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.white10),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E1E2E),
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: _C.white54, size: 18),
        items: items.map((item) {
          final isSelected = item.value == value;
          return DropdownMenuItem<T>(
            value: item.value as T,
            enabled: item.enabled,
            child: Row(children: [
              Icon(item.icon,
                  size: 14,
                  color: item.enabled
                      ? (isSelected ? _C.accent : _C.white54)
                      : _C.white24),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: item.enabled
                        ? (isSelected ? _C.accent : Colors.white)
                        : _C.white24,
                  ),
                ),
              ),
            ]),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PODIUM SECTION
// ─────────────────────────────────────────────
class _PodiumSection extends StatelessWidget {
  final bool loading;
  final List<_Row> topThree;
  final AnimationController anim;
  final String scopeFilter;

  const _PodiumSection({
    required this.loading,
    required this.topThree,
    required this.anim,
    required this.scopeFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP 3',
            style: TextStyle(
              color: _C.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            _shimmerBox(height: 176)
          else if (topThree.isEmpty)
            _LeaderboardEmptyState(
              title: 'No rankings yet',
              hint: scopeFilter == 'school'
                  ? 'Once classmates from your school play Compete, they\'ll show up here.'
                  : 'Play Compete matches to appear on the leaderboard.',
            )
          else
            _Podium(topThree: topThree, anim: anim),
        ],
      ),
    );
  }

  Widget _shimmerBox({required double height}) => Shimmer.fromColors(
        baseColor: _C.white10,
        highlightColor: _C.white24,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
}

class _Podium extends StatelessWidget {
  final List<_Row> topThree;
  final AnimationController anim;

  const _Podium({required this.topThree, required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic).value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // #2 — left
          if (topThree.length > 1)
            Expanded(child: _PodiumCard(row: topThree[1], rank: 2)),
          // #1 — center
          if (topThree.isNotEmpty)
            Expanded(child: _PodiumCard(row: topThree[0], rank: 1)),
          // #3 — right
          if (topThree.length > 2)
            Expanded(child: _PodiumCard(row: topThree[2], rank: 3)),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final _Row row;
  final int rank;

  const _PodiumCard({required this.row, required this.rank});

  @override
  Widget build(BuildContext context) {
    final double avatarSize = rank == 1 ? 72 : 56;
    final double baseHeight  = rank == 1 ? 80 : rank == 2 ? 56 : 40;
    final Color baseColor    = rank == 1
        ? _C.accent.withValues(alpha: 0.2)
        : rank == 2
            ? Colors.grey.shade800
            : _C.primary.withValues(alpha: 0.15);

    final gradient = rank == 1
        ? const LinearGradient(colors: [_C.accent, _C.primary])
        : rank == 2
            ? LinearGradient(
                colors: [Colors.grey.shade700, Colors.grey.shade500])
            : const LinearGradient(colors: [_C.primaryDk, _C.accent]);

    return Column(
      children: [
        // Crown for #1
        if (rank == 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.workspace_premium_rounded,
                color: _C.gold, size: 22),
          ),

        // Avatar
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            gradient: gradient,
            shape: BoxShape.circle,
            border: rank == 1
                ? Border.all(color: _C.accent, width: 2.5)
                : rank == 2
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.3), width: 1.5)
                    : null,
          ),
          alignment: Alignment.center,
          child: Text(
            row.initials,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: rank == 1 ? 22 : 16,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Name
        SizedBox(
          width: 100,
          child: Text(
            row.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 2),

        // Rating
        Text(
          '${row.rating}',
          style: TextStyle(
            color: rank == 1 ? _C.accent : _C.white54,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),

        // Podium base
        Container(
          height: baseHeight,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '#$rank',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TABLE SECTION (positions 4+)
// ─────────────────────────────────────────────
class _TableSection extends StatelessWidget {
  final bool loading;
  final List<_Row> rest;
  final String scopeFilter;

  const _TableSection({
    required this.loading,
    required this.rest,
    required this.scopeFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _C.white10, width: 1),
              ),
            ),
            child: Row(children: [
              const SizedBox(width: 40,
                child: Text('Rank', style: _tableHdr, maxLines: 1)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Player', style: _tableHdr, maxLines: 1)),
              const SizedBox(width: 58,
                child: Text('Rating', textAlign: TextAlign.right,
                    style: _tableHdr, maxLines: 1)),
              const SizedBox(width: 48,
                child: Text('Win %', textAlign: TextAlign.right,
                    style: _tableHdr, maxLines: 1)),
              const SizedBox(width: 44,
                child: Text('Played', textAlign: TextAlign.right,
                    style: _tableHdr, maxLines: 1)),
            ]),
          ),

          if (loading)
            Column(
              children: List.generate(
                6,
                (_) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Shimmer.fromColors(
                    baseColor: _C.white10,
                    highlightColor: _C.white24,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            )
          else if (rest.isEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35,
              child: const Center(
                child: _LeaderboardEmptyState(
                  title: 'No more players',
                  hint: 'Check back as more competitors join.',
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rest.length,
              separatorBuilder: (_, _) => Divider(
                color: _C.white10, height: 1, thickness: 1),
              itemBuilder: (_, i) => _TableRow(row: rest[i]),
            ),
        ],
      ),
    );
  }

  static const _tableHdr = TextStyle(
    color: _C.white54,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
}

class _TableRow extends StatelessWidget {
  final _Row row;
  const _TableRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: row.isYou ? _C.primary.withValues(alpha: 0.1) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        // Rank
        SizedBox(
          width: 40,
          child: Text(
            '#${row.rank}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Avatar
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _C.white10,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            row.initials,
            style: const TextStyle(
              color: _C.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Name
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(
                row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: row.isYou ? _C.accent : Colors.white,
                  fontSize: 13,
                  fontWeight: row.isYou ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (row.isYou)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Text('(You)',
                    style: TextStyle(
                      color: _C.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    )),
              ),
          ]),
        ),

        // Rating
        SizedBox(
          width: 58,
          child: Text(
            '${row.rating}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // Win rate
        SizedBox(
          width: 48,
          child: Text(
            '${row.accuracy}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _C.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        // Matches
        SizedBox(
          width: 44,
          child: Text(
            '${row.matches}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: _C.white54,
              fontSize: 13,
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// STICKY POSITION BAR
// ─────────────────────────────────────────────
class _YourPositionBar extends StatelessWidget {
  final _Row row;
  final String scopeFilter;

  const _YourPositionBar({required this.row, required this.scopeFilter});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_C.primary, _C.accent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _C.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(children: [
        Icon(
          scopeFilter == 'school'
              ? Icons.school_rounded
              : Icons.public_rounded,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 10),
        const Text(
          'Your Position',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          '#${row.rank} · ${row.rating}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────
class _LeaderboardEmptyState extends StatelessWidget {
  final String title;
  final String? hint;

  const _LeaderboardEmptyState({required this.title, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.white10,
            ),
            child: const Icon(Icons.inbox_outlined,
                color: _C.white54, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: _C.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

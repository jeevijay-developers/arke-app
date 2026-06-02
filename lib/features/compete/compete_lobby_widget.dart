import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'compete_models.dart';

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

typedef OnLobbyAction =
    void Function({
      required String action,
      required String subject,
      required String topic,
      required String classLevel,
      required String examType,
      String? roomCode,
    });

const _kClasses = ['6', '7', '8', '9', '10', '11', '12', 'Dropper'];
String _classLabel(String c) => c == 'Dropper' ? '12th Pass' : 'Class $c';

const _kExamSubjects = {
  'JEE Main': ['Physics', 'Chemistry', 'Math'],
  'JEE Advanced': ['Physics', 'Chemistry', 'Math'],
  'NEET': ['Physics', 'Chemistry', 'Biology'],
  'Boards': ['Physics', 'Chemistry', 'Math', 'Biology'],
  'Foundation': ['Physics', 'Chemistry', 'Math', 'Biology'],
};

const _kExams = ['JEE Main', 'JEE Advanced', 'NEET', 'Boards', 'Foundation'];

class CompeteLobbyWidget extends StatefulWidget {
  final CompeteRating rating;
  final bool busy;
  final String? joinError;
  final OnLobbyAction onAction;

  const CompeteLobbyWidget({
    super.key,
    required this.rating,
    required this.busy,
    this.joinError,
    required this.onAction,
  });

  @override
  State<CompeteLobbyWidget> createState() => _CompeteLobbyWidgetState();
}

class _CompeteLobbyWidgetState extends State<CompeteLobbyWidget> {
  String _classLevel = '11';
  String _examType = 'JEE Main';
  String _subject = 'Physics';
  String _topic = 'Any';
  final _codeCtrl = TextEditingController();
  String? _localJoinError;

  List<String> get _subjects => _kExamSubjects[_examType] ?? kSubjects;
  List<String> get _topics => kSubjectTopics[_subject] ?? ['Any'];

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _selectClass(String c) => setState(() => _classLevel = c);

  void _selectExam(String e) {
    setState(() {
      _examType = e;
      final subs = _kExamSubjects[e] ?? kSubjects;
      if (!subs.contains(_subject)) {
        _subject = subs.first;
        _topic = 'Any';
      }
    });
  }

  void _selectSubject(String s) => setState(() {
    _subject = s;
    _topic = 'Any';
  });
  void _selectTopic(String t) => setState(() => _topic = t);

  void _find() {
    HapticFeedback.mediumImpact();
    widget.onAction(
      action: 'find',
      subject: _subject,
      topic: _topic,
      classLevel: _classLevel,
      examType: _examType,
    );
  }

  void _bot() {
    HapticFeedback.selectionClick();
    widget.onAction(
      action: 'bot',
      subject: _subject,
      topic: _topic,
      classLevel: _classLevel,
      examType: _examType,
    );
  }

  void _create() {
    HapticFeedback.selectionClick();
    widget.onAction(
      action: 'create',
      subject: _subject,
      topic: _topic,
      classLevel: _classLevel,
      examType: _examType,
    );
  }

  void _join() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _localJoinError = 'Enter at least 4 characters');
      return;
    }
    setState(() => _localJoinError = null);
    HapticFeedback.mediumImpact();
    widget.onAction(
      action: 'join',
      subject: _subject,
      topic: _topic,
      classLevel: _classLevel,
      examType: _examType,
      roomCode: code,
    );
  }

  @override
  Widget build(BuildContext context) {
    final joinErr = widget.joinError ?? _localJoinError;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: Column(
          children: [
            _CompeteHeader(rating: widget.rating),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  DS.s16,
                  DS.s20,
                  DS.s16,
                  DS.s32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MatchSettingsCard(
                      classLevel: _classLevel,
                      examType: _examType,
                      subject: _subject,
                      topic: _topic,
                      subjects: _subjects,
                      topics: _topics,
                      busy: widget.busy,
                      onClassSelect: _selectClass,
                      onExamSelect: _selectExam,
                      onSubjSelect: _selectSubject,
                      onTopicSelect: _selectTopic,
                    ),
                    const SizedBox(height: DS.s24),
                    _FindOpponentButton(busy: widget.busy, onFind: _find),
                    const SizedBox(height: DS.s12),
                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryActionButton(
                            icon: Icons.add_box_outlined,
                            label: 'Create Room',
                            onTap: widget.busy ? null : _create,
                          ),
                        ),
                        const SizedBox(width: DS.s10),
                        Expanded(
                          child: _SecondaryActionButton(
                            icon: Icons.smart_toy_outlined,
                            label: 'vs Bot',
                            onTap: widget.busy ? null : _bot,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: DS.s24),
                    _JoinRoomCard(
                      ctrl: _codeCtrl,
                      enabled: !widget.busy,
                      joinErr: joinErr,
                      onJoin: widget.busy ? null : _join,
                      onChange: (_) {
                        if (_localJoinError != null)
                          setState(() => _localJoinError = null);
                      },
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

// ── Header ──────────────────────────────────────────────────────────────────
class _CompeteHeader extends StatelessWidget {
  final CompeteRating rating;
  const _CompeteHeader({required this.rating});

  String get _rankLabel {
    final r = rating.rating;
    if (r >= 2000) return '👑 Grandmaster';
    if (r >= 1600) return '🏆 Master';
    if (r >= 1200) return '🥇 Expert';
    if (r >= 800) return '🥈 Skilled';
    return '🥉 Beginner';
  }

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
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.go('/home'),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.30),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: DS.s12),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(DS.radiusMd),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.30),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Text('⚔️', style: TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(width: DS.s14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Compete',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              '10 questions · 30 seconds each',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: DS.s20),
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
                        const Icon(
                          Icons.military_tech_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: DS.s6),
                        Text(
                          _rankLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
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

// ── Match Settings Card ──────────────────────────────────────────────────────
class _MatchSettingsCard extends StatelessWidget {
  final String classLevel, examType, subject, topic;
  final List<String> subjects, topics;
  final bool busy;
  final void Function(String) onClassSelect,
      onExamSelect,
      onSubjSelect,
      onTopicSelect;

  const _MatchSettingsCard({
    required this.classLevel,
    required this.examType,
    required this.subject,
    required this.topic,
    required this.subjects,
    required this.topics,
    required this.busy,
    required this.onClassSelect,
    required this.onExamSelect,
    required this.onSubjSelect,
    required this.onTopicSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(DS.s16, DS.s14, DS.s16, DS.s14),
            decoration: const BoxDecoration(
              color: DS.primaryLight,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(DS.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: DS.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: DS.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: DS.s10),
                const Text(
                  'Match Settings',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: DS.primaryDark,
                    letterSpacing: -0.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s4,
                  ),
                  decoration: BoxDecoration(
                    color: DS.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '10 Qs · 30s',
                    style: TextStyle(
                      color: DS.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DS.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingRow(label: 'Class', icon: Icons.school_outlined),
                const SizedBox(height: DS.s10),
                Wrap(
                  spacing: DS.s8,
                  runSpacing: DS.s8,
                  children: _kClasses
                      .map(
                        (c) => _DSChip(
                          label: _classLabel(c),
                          selected: classLevel == c,
                          onTap: busy ? null : () => onClassSelect(c),
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: DS.s16),
                Divider(color: DS.border, height: 1),
                const SizedBox(height: DS.s16),

                _SettingRow(label: 'Exam Type', icon: Icons.quiz_outlined),
                const SizedBox(height: DS.s10),
                Wrap(
                  spacing: DS.s8,
                  runSpacing: DS.s8,
                  children: _kExams
                      .map(
                        (e) => _DSChip(
                          label: e,
                          selected: examType == e,
                          onTap: busy ? null : () => onExamSelect(e),
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: DS.s16),
                Divider(color: DS.border, height: 1),
                const SizedBox(height: DS.s16),

                _SettingRow(label: 'Subject', icon: Icons.book_outlined),
                const SizedBox(height: DS.s10),
                Wrap(
                  spacing: DS.s8,
                  runSpacing: DS.s8,
                  children: subjects
                      .map(
                        (s) => _DSChip(
                          label: s,
                          selected: subject == s,
                          onTap: busy ? null : () => onSubjSelect(s),
                          filled: true,
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: DS.s16),
                Divider(color: DS.border, height: 1),
                const SizedBox(height: DS.s16),

                _SettingRow(label: 'Topic', icon: Icons.topic_outlined),
                const SizedBox(height: DS.s10),
                Wrap(
                  spacing: DS.s8,
                  runSpacing: DS.s8,
                  children: topics
                      .map(
                        (t) => _DSChip(
                          label: t,
                          selected: topic == t,
                          onTap: busy ? null : () => onTopicSelect(t),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SettingRow({required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 16,
        decoration: BoxDecoration(
          color: DS.primary,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: DS.s8),
      Icon(icon, size: 14, color: DS.textSecondary),
      const SizedBox(width: DS.s6),
      Text(
        label,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: DS.textPrimary,
        ),
      ),
    ],
  );
}

// ── DS Chip ──────────────────────────────────────────────────────────────────
class _DSChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool filled;
  const _DSChip({
    required this.label,
    required this.selected,
    this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap?.call();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: DS.s12, vertical: DS.s8),
      decoration: BoxDecoration(
        gradient: selected && filled
            ? const LinearGradient(
                colors: [Color(0xFFFF8C38), DS.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: selected && !filled
            ? DS.primaryLight
            : !selected
            ? DS.surfaceVariant
            : null,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected
              ? DS.primary.withOpacity(filled ? 0 : 0.50)
              : DS.border,
          width: selected ? 1.4 : 1.2,
        ),
        boxShadow: selected && filled
            ? [
                BoxShadow(
                  color: DS.primary.withOpacity(0.22),
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
            Icon(
              Icons.check_rounded,
              size: 12,
              color: filled ? Colors.white : DS.primary,
            ),
            const SizedBox(width: DS.s4),
          ],
          Text(
            label,
            style: TextStyle(
              color: selected
                  ? (filled ? Colors.white : DS.primaryDark)
                  : DS.textPrimary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Find Opponent Button ─────────────────────────────────────────────────────
class _FindOpponentButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onFind;
  const _FindOpponentButton({required this.busy, required this.onFind});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: busy
            ? null
            : const LinearGradient(
                colors: [Color(0xFFFF8C38), DS.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: busy ? DS.border : null,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        boxShadow: busy
            ? []
            : [
                BoxShadow(
                  color: DS.primary.withOpacity(0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: busy ? null : onFind,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radiusMd),
          ),
        ),
        child: busy
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: DS.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: DS.s10),
                  Text(
                    'Searching for opponent…',
                    style: TextStyle(
                      color: DS.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_kabaddi_rounded, size: 20),
                  SizedBox(width: DS.s10),
                  Text(
                    'Find Opponent',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

// ── Secondary Action Button ──────────────────────────────────────────────────
class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: DS.s14),
        decoration: BoxDecoration(
          color: enabled ? DS.primaryLight : DS.surfaceVariant,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(
            color: enabled ? DS.primary.withOpacity(0.25) : DS.border,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: enabled ? DS.primary : DS.textHint),
            const SizedBox(width: DS.s8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? DS.primaryDark : DS.textHint,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Join Room Card ───────────────────────────────────────────────────────────
class _JoinRoomCard extends StatelessWidget {
  final TextEditingController ctrl;
  final bool enabled;
  final String? joinErr;
  final VoidCallback? onJoin;
  final ValueChanged<String> onChange;

  const _JoinRoomCard({
    required this.ctrl,
    required this.enabled,
    required this.joinErr,
    required this.onJoin,
    required this.onChange,
  });

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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: DS.primaryLight,
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                child: const Icon(
                  Icons.meeting_room_outlined,
                  color: DS.primary,
                  size: 17,
                ),
              ),
              const SizedBox(width: DS.s10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join a Room',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: DS.textPrimary,
                      letterSpacing: -0.1,
                    ),
                  ),
                  Text(
                    'Enter room code to join a friend',
                    style: TextStyle(fontSize: 11.5, color: DS.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: DS.s16),
          Divider(color: DS.border, height: 1),
          const SizedBox(height: DS.s16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(
                    color: DS.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                  decoration: InputDecoration(
                    hintText: 'XXXXXX',
                    hintStyle: const TextStyle(
                      color: DS.textHint,
                      letterSpacing: 4,
                      fontSize: 18,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: DS.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DS.s16,
                      vertical: DS.s14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                      borderSide: const BorderSide(
                        color: DS.border,
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                      borderSide: const BorderSide(
                        color: DS.primary,
                        width: 1.8,
                      ),
                    ),
                    errorText: joinErr,
                    errorStyle: const TextStyle(
                      color: DS.error,
                      fontSize: 11.5,
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                      borderSide: const BorderSide(color: DS.error, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                      borderSide: const BorderSide(color: DS.error, width: 1.8),
                    ),
                  ),
                  onChanged: onChange,
                ),
              ),
              const SizedBox(width: DS.s10),
              SizedBox(
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: onJoin != null
                        ? const LinearGradient(
                            colors: [Color(0xFFFF8C38), DS.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: onJoin == null ? DS.border : null,
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                    boxShadow: onJoin != null
                        ? [
                            BoxShadow(
                              color: DS.primary.withOpacity(0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: ElevatedButton(
                    onPressed: onJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: DS.s20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                    ),
                    child: Text(
                      'Join',
                      style: TextStyle(
                        color: onJoin != null ? Colors.white : DS.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
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

// Placeholder constants — replace with actual compete_models.dart imports
const kSubjects = ['Physics', 'Chemistry', 'Math', 'Biology'];
const kSubjectTopics = <String, List<String>>{
  'Physics': ['Any', 'Mechanics', 'Waves', 'Optics', 'Modern Physics'],
  'Chemistry': ['Any', 'Organic', 'Inorganic', 'Physical'],
  'Math': ['Any', 'Algebra', 'Calculus', 'Coordinate Geometry'],
  'Biology': ['Any', 'Botany', 'Zoology', 'Human Physiology'],
};

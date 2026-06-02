import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../skeleton_loading/doubt_skeleton.dart';
import '../doubts/data/doubts_providers.dart';
import '../doubts/data/models/doubt.dart';

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
  static const indigo = Color(0xFF6366F1);
  static const indigoLight = Color(0xFFEEF2FF);
  static const teal = Color(0xFF14B8A6);
  static const tealLight = Color(0xFFF0FDFA);

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
// SUBJECTS LIST
// ─────────────────────────────────────────────
const _subjects = [
  'Physics',
  'Chemistry',
  'Mathematics',
  'Biology',
  'History',
  'Geography',
  'English',
  'Economics',
  'Computer Science',
  'General',
];

// ─────────────────────────────────────────────
// DOUBTS SCREEN
// ─────────────────────────────────────────────
class DoubtsScreen extends ConsumerStatefulWidget {
  const DoubtsScreen({super.key});

  @override
  ConsumerState<DoubtsScreen> createState() => _DoubtsScreenState();
}

class _DoubtsScreenState extends ConsumerState<DoubtsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabLabels = ['All', 'Pending', 'AI Solved', 'Answered'];

  static const _tabIcons = [
    Icons.list_rounded,
    Icons.hourglass_bottom_rounded,
    Icons.auto_awesome_rounded,
    Icons.check_circle_outline_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<Doubt> _filter(List<Doubt> all, int tab) {
    switch (tab) {
      case 1:
        return all.where((d) => d.isPending).toList();
      case 2:
        return all.where((d) => d.isAiSolved).toList();
      case 3:
        return all.where((d) => d.isAnswered && !d.isAiSolved).toList();
      default:
        return all;
    }
  }

  void _openAskSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: DS.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusXl)),
      ),
      builder: (_) =>
          _AskDoubtSheet(onSubmitted: () => ref.invalidate(doubtsProvider)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doubtsAsync = ref.watch(doubtsProvider);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: DS.background,

        // ── Custom AppBar ──
        appBar: _DoubtsAppBar(
          onBack: () => context.canPop() ? context.pop() : context.go('/home'),
          onAskDoubt: _openAskSheet,
          tabs: _tabs,
          tabLabels: _tabLabels,
          tabIcons: _tabIcons,
        ),

        body: doubtsAsync.when(
          loading: () => const DoubtSkeleton(),
          error: (e, _) => _ErrorState(message: 'Error: $e'),
          data: (all) => TabBarView(
            controller: _tabs,
            children: List.generate(4, (i) {
              final items = _filter(all, i);
              if (items.isEmpty) {
                return _EmptyDoubtsState(
                  tabIndex: i,
                  onAskDoubt: _openAskSheet,
                );
              }
              return RefreshIndicator(
                color: DS.primary,
                onRefresh: () async => ref.invalidate(doubtsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    DS.s16,
                    DS.s16,
                    DS.s16,
                    100,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: DS.s10),
                  itemBuilder: (_, idx) => _DoubtCard(doubt: items[idx]),
                ),
              );
            }),
          ),
        ),

        // ── FAB ──
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAskSheet,
          backgroundColor: DS.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radiusMd),
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text(
            'Ask Doubt',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CUSTOM APP BAR
// ─────────────────────────────────────────────
class _DoubtsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onBack;
  final VoidCallback onAskDoubt;
  final TabController tabs;
  final List<String> tabLabels;
  final List<IconData> tabIcons;

  const _DoubtsAppBar({
    required this.onBack,
    required this.onAskDoubt,
    required this.tabs,
    required this.tabLabels,
    required this.tabIcons,
  });

  @override
  Size get preferredSize => const Size.fromHeight(112);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(bottom: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DS.s8,
                vertical: DS.s8,
              ),
              child: Row(
                children: [
                  // Back
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: DS.primaryLight,
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                        border: Border.all(
                          color: DS.primary.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: DS.primary,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: DS.s12),

                  // Title
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 28,
                        decoration: BoxDecoration(
                          color: DS.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: DS.s10),
                      const Text(
                        'My Doubts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: DS.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: tabs,
              labelColor: DS.primary,
              unselectedLabelColor: DS.textSecondary,
              indicatorColor: DS.primary,
              indicatorWeight: 2.5,
              indicatorSize: TabBarIndicatorSize.label,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: DS.s8),
              tabs: List.generate(
                tabLabels.length,
                (i) => Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tabIcons[i], size: 14),
                      const SizedBox(width: DS.s4),
                      Text(tabLabels[i]),
                    ],
                  ),
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
// EMPTY STATE
// ─────────────────────────────────────────────
class _EmptyDoubtsState extends StatelessWidget {
  final int tabIndex;
  final VoidCallback onAskDoubt;

  const _EmptyDoubtsState({required this.tabIndex, required this.onAskDoubt});

  static const _messages = [
    'No doubts yet',
    'No pending doubts',
    'No AI-solved doubts yet',
    'No educator answers yet',
  ];

  static const _subtitles = [
    'Ask your first doubt and get\nan instant AI answer!',
    'All caught up! No pending doubts.',
    'Submit a doubt and choose AI\nfor an instant answer.',
    'Ask an educator for complex\ndoubts that need expert guidance.',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C38), DS.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(DS.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: DS.primary.withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.help_outline_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: DS.s20),
            Text(
              _messages[tabIndex],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DS.s8),
            Text(
              _subtitles[tabIndex],
              style: const TextStyle(
                fontSize: 13.5,
                color: DS.textSecondary,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DS.s24),
            if (tabIndex == 0)
              GestureDetector(
                onTap: onAskDoubt,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s20,
                    vertical: DS.s12,
                  ),
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
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      SizedBox(width: DS.s8),
                      Text(
                        'Ask your first doubt',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
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
// DOUBT CARD
// ─────────────────────────────────────────────
class _DoubtCard extends ConsumerStatefulWidget {
  final Doubt doubt;
  const _DoubtCard({required this.doubt});

  @override
  ConsumerState<_DoubtCard> createState() => _DoubtCardState();
}

class _DoubtCardState extends ConsumerState<_DoubtCard> {
  bool _expanded = false;

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // Status → color / label / icon
  Color get _statusColor {
    if (widget.doubt.isAiSolved) return DS.indigo;
    if (widget.doubt.isAnswered) return DS.teal;
    return DS.warning;
  }

  String get _statusLabel {
    if (widget.doubt.isAiSolved) return 'AI Solved';
    if (widget.doubt.isAnswered) return 'Answered';
    return 'Pending';
  }

  IconData get _statusIcon {
    if (widget.doubt.isAiSolved) return Icons.auto_awesome_rounded;
    if (widget.doubt.isAnswered) return Icons.check_circle_rounded;
    return Icons.hourglass_bottom_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final doubt = widget.doubt;
    final answersAsync = _expanded
        ? ref.watch(doubtAnswersProvider(doubt.id))
        : null;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _expanded = !_expanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(DS.s14),
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(
            color: _expanded ? DS.primary : DS.border,
            width: _expanded ? 1.6 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _expanded
                  ? DS.primary.withOpacity(0.08)
                  : Colors.black.withOpacity(0.03),
              blurRadius: _expanded ? 12 : 6,
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
                // Subject chip
                _StatusChip(
                  label: doubt.subject,
                  color: DS.primary,
                  bg: DS.primaryLight,
                ),
                const SizedBox(width: DS.s6),

                // Routed to chip
                if (doubt.routedTo == 'ai')
                  _StatusChip(
                    label: '✨ AI',
                    color: DS.indigo,
                    bg: DS.indigoLight,
                  )
                else
                  _StatusChip(
                    label: '👨‍🏫 Educator',
                    color: DS.teal,
                    bg: DS.tealLight,
                  ),

                const Spacer(),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s8,
                    vertical: DS.s4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _statusColor.withOpacity(0.20),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon, size: 11, color: _statusColor),
                      const SizedBox(width: DS.s4),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: DS.s8),
                Text(
                  _timeAgo(doubt.createdAt),
                  style: const TextStyle(color: DS.textHint, fontSize: 11),
                ),
                const SizedBox(width: DS.s4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: DS.textSecondary,
                    size: 18,
                  ),
                ),
              ],
            ),

            const SizedBox(height: DS.s12),

            // ── Question text ──
            Text(
              doubt.questionText,
              style: const TextStyle(
                color: DS.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
              maxLines: _expanded ? null : 3,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),

            // ── AI Answer ──
            if (doubt.aiAnswer != null && doubt.aiAnswer!.isNotEmpty) ...[
              const SizedBox(height: DS.s12),
              _AiAnswerCard(answer: doubt.aiAnswer!, expanded: _expanded),
            ] else if (doubt.isPending) ...[
              const SizedBox(height: DS.s12),
              _PendingIndicator(),
            ],

            // ── Educator Answers (when expanded) ──
            if (_expanded && answersAsync != null)
              answersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: DS.s14),
                  child: Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: DS.primary,
                      ),
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(top: DS.s10),
                  child: Text(
                    'Could not load answers: $e',
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                data: (answers) {
                  final teacher = answers.where((a) => a.isTeacher).toList();
                  if (teacher.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: DS.s16),
                      // Section label
                      Row(
                        children: [
                          Container(
                            width: 3,
                            height: 16,
                            decoration: BoxDecoration(
                              color: DS.teal,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: DS.s8),
                          const Text(
                            'Educator Answer',
                            style: TextStyle(
                              color: DS.teal,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DS.s10),
                      ...teacher.map(
                        (ans) => _EducatorAnswerBubble(answer: ans),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AI ANSWER CARD
// ─────────────────────────────────────────────
class _AiAnswerCard extends StatelessWidget {
  final String answer;
  final bool expanded;
  const _AiAnswerCard({required this.answer, required this.expanded});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DS.s12),
      decoration: BoxDecoration(
        color: DS.indigoLight,
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: DS.indigo.withOpacity(0.20), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: DS.indigo.withOpacity(0.15),
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: DS.indigo,
            ),
          ),
          const SizedBox(width: DS.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Answer',
                  style: TextStyle(
                    color: DS.indigo,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: DS.s4),
                Text(
                  answer,
                  style: const TextStyle(
                    color: DS.textPrimary,
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                  maxLines: expanded ? null : 3,
                  overflow: expanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
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
// PENDING INDICATOR
// ─────────────────────────────────────────────
class _PendingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s12, vertical: DS.s10),
      decoration: BoxDecoration(
        color: DS.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: DS.warning.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 13,
            width: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: DS.warning),
          ),
          const SizedBox(width: DS.s10),
          const Text(
            'Awaiting answer…',
            style: TextStyle(
              color: DS.warning,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EDUCATOR ANSWER BUBBLE
// ─────────────────────────────────────────────
class _EducatorAnswerBubble extends StatelessWidget {
  final dynamic answer;
  const _EducatorAnswerBubble({required this.answer});

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(answer.createdAt as DateTime);
    final timeAgo = diff.inMinutes < 60
        ? '${diff.inMinutes}m ago'
        : diff.inHours < 24
        ? '${diff.inHours}h ago'
        : '${diff.inDays}d ago';

    return Container(
      margin: const EdgeInsets.only(bottom: DS.s8),
      padding: const EdgeInsets.all(DS.s12),
      decoration: BoxDecoration(
        color: DS.tealLight,
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: DS.teal.withOpacity(0.20), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teacher badge row
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: DS.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 14,
                  color: DS.teal,
                ),
              ),
              const SizedBox(width: DS.s8),
              const Text(
                'Teacher',
                style: TextStyle(
                  color: DS.teal,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                timeAgo,
                style: const TextStyle(color: DS.textHint, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: DS.s10),

          // Answer text
          Text(
            answer.answerText as String,
            style: const TextStyle(
              color: DS.textPrimary,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),

          // Helpful count
          if ((answer.helpfulCount as int) > 0) ...[
            const SizedBox(height: DS.s8),
            Row(
              children: [
                const Icon(Icons.thumb_up_rounded, size: 12, color: DS.teal),
                const SizedBox(width: DS.s4),
                Text(
                  '${answer.helpfulCount} found helpful',
                  style: const TextStyle(
                    color: DS.teal,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STATUS CHIP
// ─────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color, bg;
  const _StatusChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ASK DOUBT BOTTOM SHEET
// ─────────────────────────────────────────────
class _AskDoubtSheet extends ConsumerStatefulWidget {
  final VoidCallback onSubmitted;
  const _AskDoubtSheet({required this.onSubmitted});

  @override
  ConsumerState<_AskDoubtSheet> createState() => _AskDoubtSheetState();
}

class _AskDoubtSheetState extends ConsumerState<_AskDoubtSheet> {
  String _subject = _subjects.first;
  String _routedTo = 'ai';
  bool _loading = false;
  String? _error;
  String _loadingLabel = '';

  final _questionCtrl = TextEditingController();

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final q = _questionCtrl.text.trim();
    if (q.isEmpty) {
      setState(() => _error = 'Please describe your doubt.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _loading = true;
      _error = null;
      _loadingLabel = 'Submitting…';
    });

    try {
      final repo = ref.read(doubtsRepositoryProvider);
      final doubt = await repo.submitDoubt(
        subject: _subject,
        questionText: q,
        routedTo: _routedTo,
      );

      if (_routedTo == 'ai') {
        setState(() => _loadingLabel = 'AI is solving your doubt…');
        try {
          await repo.callAiSolver(
            doubtId: doubt.id,
            subject: _subject,
            question: q,
          );
        } catch (aiErr) {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = 'Doubt saved, but AI failed: $aiErr';
            });
            return;
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _routedTo == 'ai'
                  ? '✨ AI has answered your doubt!'
                  : '👨‍🏫 Sent to educator — you\'ll be notified when answered.',
            ),
            backgroundColor: DS.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to submit: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isAi = _routedTo == 'ai';

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(DS.s24, DS.s20, DS.s24, DS.s28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: DS.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: DS.s16),

            // Title row
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8C38), DS.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DS.s12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask a Doubt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: DS.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Get instant AI or educator help',
                        style: TextStyle(fontSize: 12, color: DS.textSecondary),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: DS.surfaceVariant,
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: DS.textSecondary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: DS.s24),

            // ── Subject dropdown ──
            _SheetLabel(label: 'Subject'),
            const SizedBox(height: DS.s8),
            Container(
              decoration: BoxDecoration(
                color: DS.surface,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(color: DS.border, width: 1.2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: DS.s12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _subject,
                  isExpanded: true,
                  dropdownColor: DS.surface,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: DS.textSecondary,
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: DS.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  items: _subjects
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _subject = v!),
                ),
              ),
            ),

            const SizedBox(height: DS.s16),

            // ── Question textarea ──
            _SheetLabel(label: 'Your question'),
            const SizedBox(height: DS.s8),
            TextField(
              controller: _questionCtrl,
              maxLines: 5,
              style: const TextStyle(fontSize: 14.5, color: DS.textPrimary),
              decoration: InputDecoration(
                hintText: 'Describe your doubt clearly…',
                hintStyle: const TextStyle(color: DS.textHint, fontSize: 14),
                filled: true,
                fillColor: DS.background,
                contentPadding: const EdgeInsets.all(DS.s14),
                errorText: _error,
                errorStyle: const TextStyle(color: DS.error, fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  borderSide: const BorderSide(color: DS.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  borderSide: const BorderSide(color: DS.border, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  borderSide: const BorderSide(color: DS.primary, width: 1.8),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  borderSide: const BorderSide(color: DS.error),
                ),
              ),
            ),

            const SizedBox(height: DS.s16),

            // ── Attach image ──
            _SheetLabel(label: 'Attach image (optional)'),
            const SizedBox(height: DS.s8),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text('Choose file'),
              style: OutlinedButton.styleFrom(
                foregroundColor: DS.textSecondary,
                side: const BorderSide(color: DS.border, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s14,
                  vertical: DS.s10,
                ),
              ),
            ),

            const SizedBox(height: DS.s20),

            // ── Who should answer ──
            _SheetLabel(label: 'Who should answer?'),
            const SizedBox(height: DS.s10),
            Row(
              children: [
                Expanded(
                  child: _AnswerOption(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI',
                    subtitle: 'Instant answer',
                    color: DS.indigo,
                    selected: _routedTo == 'ai',
                    onTap: () => setState(() => _routedTo = 'ai'),
                  ),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: _AnswerOption(
                    icon: Icons.school_outlined,
                    title: 'Educator',
                    subtitle: 'Best for complex doubts',
                    color: DS.teal,
                    selected: _routedTo == 'educator',
                    onTap: () => setState(() => _routedTo = 'educator'),
                  ),
                ),
              ],
            ),

            // AI disclaimer
            if (isAi) ...[
              const SizedBox(height: DS.s12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DS.s12,
                  vertical: DS.s10,
                ),
                decoration: BoxDecoration(
                  color: DS.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                  border: Border.all(color: DS.warning.withOpacity(0.25)),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: DS.warning,
                    ),
                    SizedBox(width: DS.s8),
                    Expanded(
                      child: Text(
                        'AI answers may be incorrect. For complex doubts, choose an educator.',
                        style: TextStyle(
                          color: DS.textPrimary,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: DS.s24),

            // ── Submit button ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _loading
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFFF8C38), DS.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: _loading ? DS.border : null,
                  borderRadius: BorderRadius.circular(DS.radiusMd),
                  boxShadow: _loading
                      ? []
                      : [
                          BoxShadow(
                            color: DS.primary.withOpacity(0.30),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.radiusMd),
                    ),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isAi
                              ? Icons.auto_awesome_rounded
                              : Icons.send_rounded,
                          size: 18,
                        ),
                  label: Text(
                    _loading && _loadingLabel.isNotEmpty
                        ? _loadingLabel
                        : isAi
                        ? 'Submit & Get AI Answer'
                        : 'Submit to Educator',
                    style: const TextStyle(
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
    );
  }
}

// ─────────────────────────────────────────────
// ANSWER OPTION CARD
// ─────────────────────────────────────────────
class _AnswerOption extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _AnswerOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(DS.s12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.08) : DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(
            color: selected ? color : DS.border,
            width: selected ? 1.8 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.15) : DS.surfaceVariant,
                borderRadius: BorderRadius.circular(DS.radiusSm),
              ),
              child: Icon(
                icon,
                size: 16,
                color: selected ? color : DS.textSecondary,
              ),
            ),
            const SizedBox(width: DS.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? color : DS.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHEET LABEL
// ─────────────────────────────────────────────
class _SheetLabel extends StatelessWidget {
  final String label;
  const _SheetLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: DS.textPrimary,
    ),
  );
}

// ─────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: DS.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: DS.error,
                size: 28,
              ),
            ),
            const SizedBox(height: DS.s16),
            Text(
              message,
              style: const TextStyle(color: DS.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

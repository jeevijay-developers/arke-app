import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'data/live_providers.dart';
import 'data/models/live_class.dart';

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
  static const teal = Color(0xFF14B8A6);
  static const purple = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF06B6D4);
  static const pink = Color(0xFFEC4899);

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
// LIVE LIST SCREEN
// ─────────────────────────────────────────────
class LiveListScreen extends ConsumerStatefulWidget {
  const LiveListScreen({super.key});

  @override
  ConsumerState<LiveListScreen> createState() => _LiveListScreenState();
}

class _LiveListScreenState extends ConsumerState<LiveListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _sortSubject;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  List<LiveClass> _filtered(List<LiveClass> list) {
    if (_sortSubject == null) return list;
    return list.where((lc) => lc.subject == _sortSubject).toList();
  }

  void _showFilterSheet(List<LiveClass> all) {
    final subjects = all.map((lc) => lc.subject).toSet().toList()..sort();
    showModalBottomSheet(
      context: context,
      backgroundColor: DS.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DS.radiusXl)),
      ),
      builder: (_) => _FilterSheet(
        subjects: subjects,
        selected: _sortSubject,
        onSelect: (s) {
          setState(() => _sortSubject = s);
          Navigator.pop(context);
        },
        onClear: () {
          setState(() => _sortSubject = null);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(accessibleLiveClassesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/student-dashboard');
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: async.when(
          loading: () => const _LoadingState(),
          error: (e, _) => _ErrorState(
            message: 'Failed to load: $e',
            onRetry: () => ref.invalidate(accessibleLiveClassesProvider),
          ),
          data: (classes) {
            final now = DateTime.now();
            final todayLocal = DateTime(now.year, now.month, now.day);

            // Today & Live tab: currently live + today's classes
            final today = _filtered(
              classes.where((lc) {
                if (lc.isLive) return true;
                if (lc.isPast) return false;
                final local = lc.startsAt.toLocal();
                final classDay = DateTime(local.year, local.month, local.day);
                return classDay == todayLocal || lc.startsAt.isBefore(now);
              }).toList(),
            );

            // Upcoming: future classes beyond today
            final upcoming = _filtered(
              classes.where((lc) {
                if (lc.isLive || lc.isPast) return false;
                final local = lc.startsAt.toLocal();
                final classDay = DateTime(local.year, local.month, local.day);
                return classDay.isAfter(todayLocal);
              }).toList(),
            );

            // Count live now
            final liveCount = classes.where((lc) => lc.isLive).length;

            return Column(
              children: [
                _LiveHeader(
                  totalClasses: today.length + upcoming.length,
                  liveCount: liveCount,
                  sortSubject: _sortSubject,
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/student-dashboard'),
                  onFilter: () => _showFilterSheet(classes),
                  tabCtrl: _tabs,
                ),

                if (_sortSubject != null)
                  _ActiveFilterBanner(
                    subject: _sortSubject!,
                    count: today.length + upcoming.length,
                    onClear: () => setState(() => _sortSubject = null),
                  ),

                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _ClassList(
                        items: today,
                        emptyLabel: _sortSubject != null
                            ? 'No $_sortSubject classes today'
                            : 'No live or scheduled classes today',
                        emptyIcon: Icons.sensors_rounded,
                        showClear: _sortSubject != null,
                        onClearFilter: () =>
                            setState(() => _sortSubject = null),
                      ),
                      _ClassList(
                        items: upcoming,
                        emptyLabel: _sortSubject != null
                            ? 'No upcoming $_sortSubject classes'
                            : 'No upcoming classes scheduled',
                        emptyIcon: Icons.calendar_month_rounded,
                        showClear: _sortSubject != null,
                        onClearFilter: () =>
                            setState(() => _sortSubject = null),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────
// LIVE HEADER
// ─────────────────────────────────────────────
class _LiveHeader extends StatelessWidget {
  final int totalClasses, liveCount;
  final String? sortSubject;
  final VoidCallback onBack, onFilter;
  final TabController tabCtrl;

  const _LiveHeader({
    required this.totalClasses,
    required this.liveCount,
    required this.sortSubject,
    required this.onBack,
    required this.onFilter,
    required this.tabCtrl,
  });

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
            child: Column(
              children: [
                // ── Title row ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DS.s8,
                    DS.s8,
                    DS.s12,
                    DS.s16,
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

                      // Title + live count
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Live Classes',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                if (liveCount > 0) ...[
                                  const SizedBox(width: DS.s8),
                                  _LivePulseBadge(count: liveCount),
                                ],
                              ],
                            ),
                            Text(
                              '$totalClasses classes available',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filter
                      GestureDetector(
                        onTap: onFilter,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(
                                  DS.radiusSm,
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            if (sortSubject != null)
                              Positioned(
                                top: -3,
                                right: -3,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: DS.surface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: DS.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.all(1.5),
                                    decoration: const BoxDecoration(
                                      color: DS.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tab bar ──
                TabBar(
                  controller: tabCtrl,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.60),
                  indicatorColor: Colors.white,
                  indicatorWeight: 2.5,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sensors_rounded, size: 14),
                          SizedBox(width: DS.s6),
                          Text('Today & Live'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month_rounded, size: 14),
                          SizedBox(width: DS.s6),
                          Text('Upcoming'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DS.s4),
              ],
            ),
          ),
        ),

        // Decorative circles
        Positioned(
          top: -50,
          right: -30,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          top: 15,
          right: 20,
          child: Container(
            width: 48,
            height: 48,
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
// LIVE PULSE BADGE (animated)
// ─────────────────────────────────────────────
class _LivePulseBadge extends StatefulWidget {
  final int count;
  const _LivePulseBadge({required this.count});

  @override
  State<_LivePulseBadge> createState() => _LivePulseBadgeState();
}

class _LivePulseBadgeState extends State<_LivePulseBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s3),
        decoration: BoxDecoration(
          color: DS.error,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: DS.error.withOpacity(0.40),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: DS.s4),
            Text(
              '${widget.count} LIVE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACTIVE FILTER BANNER
// ─────────────────────────────────────────────
class _ActiveFilterBanner extends StatelessWidget {
  final String subject;
  final int count;
  final VoidCallback onClear;

  const _ActiveFilterBanner({
    required this.subject,
    required this.count,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s12, DS.s16, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s10,
              vertical: DS.s6,
            ),
            decoration: BoxDecoration(
              color: DS.primaryLight,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: DS.primary.withOpacity(0.25), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.filter_list_rounded,
                  size: 12,
                  color: DS.primary,
                ),
                const SizedBox(width: DS.s4),
                Text(
                  subject,
                  style: const TextStyle(
                    color: DS.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: DS.s6),
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: DS.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: DS.s8),
          Text(
            '$count result${count == 1 ? '' : 's'}',
            style: const TextStyle(color: DS.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CLASS LIST
// ─────────────────────────────────────────────
class _ClassList extends StatelessWidget {
  final List<LiveClass> items;
  final String emptyLabel;
  final IconData emptyIcon;
  final bool showClear;
  final VoidCallback onClearFilter;

  const _ClassList({
    required this.items,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.showClear,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyTab(
        icon: emptyIcon,
        message: emptyLabel,
        showClear: showClear,
        onClearFilter: onClearFilter,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s32),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: DS.s12),
      itemBuilder: (_, i) => _ClassCard(lc: items[i], index: i),
    );
  }
}

// ─────────────────────────────────────────────
// CLASS CARD
// ─────────────────────────────────────────────
class _ClassCard extends StatelessWidget {
  final LiveClass lc;
  final int index;

  // Accent colors cycling through palette
  static const _accentColors = [
    DS.primary,
    DS.indigo,
    DS.teal,
    DS.success,
    DS.warning,
    DS.purple,
    DS.cyan,
    DS.pink,
  ];

  const _ClassCard({required this.lc, required this.index});

  Color get _accent => _accentColors[index % _accentColors.length];

  @override
  Widget build(BuildContext context) {
    final isLive = lc.isLive;
    final startsIn = lc.startsAt.difference(DateTime.now());
    final soon = !isLive && startsIn.inMinutes <= 15 && startsIn.inMinutes >= 0;

    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(
          color: isLive
              ? DS.error.withOpacity(0.35)
              : soon
              ? DS.warning.withOpacity(0.35)
              : DS.border,
          width: isLive || soon ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isLive
                ? DS.error.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            blurRadius: isLive ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Accent top bar ──
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: isLive
                  ? const LinearGradient(
                      colors: [Color(0xFFFF6B6B), DS.error],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : LinearGradient(
                      colors: [_accent.withOpacity(0.70), _accent],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(DS.radiusMd),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(DS.s14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status + subject row ──
                Row(
                  children: [
                    if (isLive)
                      _LiveStatusBadge()
                    else if (soon)
                      _SoonBadge(minutesLeft: startsIn.inMinutes)
                    else
                      _TimeBadge(time: _fmtTime(lc.startsAt)),
                    const SizedBox(width: DS.s8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DS.s8,
                          vertical: DS.s4,
                        ),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          lc.subject,
                          style: TextStyle(
                            color: _accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: DS.s12),

                // ── Title ──
                Text(
                  lc.title,
                  style: const TextStyle(
                    color: DS.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    height: 1.3,
                  ),
                ),

                // ── Description ──
                if (lc.description != null && lc.description!.isNotEmpty) ...[
                  const SizedBox(height: DS.s6),
                  Text(
                    lc.description!,
                    style: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: DS.s14),

                // ── Divider ──
                Divider(color: DS.border, height: 1, thickness: 1),
                const SizedBox(height: DS.s12),

                // ── Educator + action ──
                Row(
                  children: [
                    // Educator avatar
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _accent.withOpacity(0.25),
                          width: 1.5,
                        ),
                      ),
                      child:
                          lc.educatorAvatar != null &&
                              lc.educatorAvatar!.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                lc.educatorAvatar!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              Icons.person_rounded,
                              color: _accent,
                              size: 16,
                            ),
                    ),
                    const SizedBox(width: DS.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lc.educatorName,
                            style: const TextStyle(
                              color: DS.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Time label for non-live
                          if (!isLive)
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 11,
                                  color: soon ? DS.warning : DS.textHint,
                                ),
                                const SizedBox(width: DS.s3),
                                Text(
                                  _fmtFull(lc.startsAt),
                                  style: TextStyle(
                                    color: soon ? DS.warning : DS.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // Action button
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        context.push('/live/${lc.id}');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DS.s14,
                          vertical: DS.s10,
                        ),
                        decoration: BoxDecoration(
                          gradient: isLive
                              ? const LinearGradient(
                                  colors: [Color(0xFFFF6B6B), DS.error],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : LinearGradient(
                                  colors: [_accent.withOpacity(0.80), _accent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(DS.radiusSm),
                          boxShadow: [
                            BoxShadow(
                              color: (isLive ? DS.error : _accent).withOpacity(
                                0.28,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLive
                                  ? Icons.sensors_rounded
                                  : Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: DS.s6),
                            Text(
                              isLive ? 'Join Live' : 'Details',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime d) {
    final diff = d.difference(DateTime.now());
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'In ${diff.inHours}h';
    final h = d.toLocal().hour.toString().padLeft(2, '0');
    final m = d.toLocal().minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtFull(DateTime d) {
    final now = DateTime.now();
    final diff = d.difference(now);
    if (diff.inMinutes < 60) return 'In ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'In ${diff.inHours}h';
    final h = d.toLocal().hour.toString().padLeft(2, '0');
    final m = d.toLocal().minute.toString().padLeft(2, '0');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} · $h:$m';
  }
}

// ─────────────────────────────────────────────
// STATUS BADGES
// ─────────────────────────────────────────────
class _LiveStatusBadge extends StatefulWidget {
  @override
  State<_LiveStatusBadge> createState() => _LiveStatusBadgeState();
}

class _LiveStatusBadgeState extends State<_LiveStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _blink;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _blink = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s10, vertical: DS.s6),
      decoration: BoxDecoration(
        color: DS.error,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: DS.error.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _blink,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: DS.s6),
          const Text(
            'LIVE NOW',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoonBadge extends StatelessWidget {
  final int minutesLeft;
  const _SoonBadge({required this.minutesLeft});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s10, vertical: DS.s6),
    decoration: BoxDecoration(
      color: DS.warningSurface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: DS.warning.withOpacity(0.40), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.timer_outlined, size: 12, color: DS.warning),
        const SizedBox(width: DS.s4),
        Text(
          'In ${minutesLeft}m',
          style: const TextStyle(
            color: DS.warning,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    ),
  );
}

class _TimeBadge extends StatelessWidget {
  final String time;
  const _TimeBadge({required this.time});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s4),
    decoration: BoxDecoration(
      color: DS.surfaceVariant,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: DS.border, width: 1),
    ),
    child: Text(
      time,
      style: const TextStyle(
        color: DS.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// FILTER SHEET
// ─────────────────────────────────────────────
class _FilterSheet extends StatelessWidget {
  final List<String> subjects;
  final String? selected;
  final void Function(String?) onSelect;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.subjects,
    required this.selected,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(DS.s24, DS.s20, DS.s24, DS.s28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DS.primaryLight,
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: DS.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: DS.s12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter by Subject',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: DS.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Select a subject to filter classes',
                      style: TextStyle(fontSize: 12, color: DS.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selected != null)
                GestureDetector(
                  onTap: onClear,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s10,
                      vertical: DS.s6,
                    ),
                    decoration: BoxDecoration(
                      color: DS.errorSurface,
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        color: DS.error,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DS.s20),

          // Subject chips
          Wrap(
            spacing: DS.s8,
            runSpacing: DS.s8,
            children: [
              _SubjectChip(
                label: 'All Subjects',
                selected: selected == null,
                onTap: () => onSelect(null),
              ),
              ...subjects.map(
                (s) => _SubjectChip(
                  label: s,
                  selected: selected == s,
                  onTap: () => onSelect(s),
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
// SUBJECT CHIP
// ─────────────────────────────────────────────
class _SubjectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.label,
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
        padding: const EdgeInsets.symmetric(
          horizontal: DS.s14,
          vertical: DS.s8,
        ),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFFFF8C38), DS.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : DS.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? DS.primary : DS.border,
            width: selected ? 0 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: DS.primary.withOpacity(0.25),
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
              const Icon(Icons.check_rounded, color: Colors.white, size: 13),
              const SizedBox(width: DS.s4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : DS.textPrimary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY TAB
// ─────────────────────────────────────────────
class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool showClear;
  final VoidCallback onClearFilter;

  const _EmptyTab({
    required this.icon,
    required this.message,
    required this.showClear,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
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
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: DS.s20),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: DS.textPrimary,
                letterSpacing: -0.1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DS.s8),
            const Text(
              'Check back later for scheduled classes',
              style: TextStyle(color: DS.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (showClear) ...[
              const SizedBox(height: DS.s20),
              GestureDetector(
                onTap: onClearFilter,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s20,
                    vertical: DS.s10,
                  ),
                  decoration: BoxDecoration(
                    color: DS.primaryLight,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: DS.primary.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_list_off_rounded,
                        size: 15,
                        color: DS.primary,
                      ),
                      SizedBox(width: DS.s6),
                      Text(
                        'Clear filter',
                        style: TextStyle(
                          color: DS.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOADING STATE
// ─────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: DS.background,
    body: Center(
      child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
    ),
  );
}

// ─────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(DS.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: DS.errorSurface,
                  borderRadius: BorderRadius.circular(DS.radiusLg),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: DS.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: DS.s16),
              Text(
                message,
                style: const TextStyle(color: DS.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: DS.s20),
              SizedBox(
                height: 46,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8C38), DS.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Retry',
                      style: TextStyle(
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
      ),
    );
  }
}

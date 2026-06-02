import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../skeleton_loading/notification_skeleton.dart';

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
// MODEL
// ─────────────────────────────────────────────
class AppNotification {
  final String id;
  final String title;
  final String? body;
  final String type;
  final String? link;
  final bool isRead;
  final bool isArchived;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    required this.type,
    this.link,
    required this.isRead,
    required this.isArchived,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    return AppNotification(
      id: j['id'] as String,
      title: j['title'] as String? ?? '',
      body: j['body'] as String?,
      type: j['type'] as String? ?? 'system',
      link: j['link'] as String?,
      isRead: j['read_at'] != null,
      isArchived: j['archived_at'] != null,
      createdAt:
          DateTime.tryParse(j['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    body: body,
    type: type,
    link: link,
    isRead: isRead ?? this.isRead,
    isArchived: isArchived,
    createdAt: createdAt,
  );
}

// ─────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────
final _notificationsProvider =
    StateNotifierProvider.autoDispose<
      _NotifNotifier,
      AsyncValue<List<AppNotification>>
    >((ref) => _NotifNotifier());

class _NotifNotifier extends StateNotifier<AsyncValue<List<AppNotification>>> {
  _NotifNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  final _db = Supabase.instance.client;
  RealtimeChannel? _channel;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    try {
      final userId = _db.auth.currentUser?.id;
      if (userId == null) {
        state = const AsyncValue.data([]);
        return;
      }

      final data = await _db
          .from('notifications')
          .select(
            'id, title, body, type, link, read_at, archived_at, created_at',
          )
          .eq('user_id', userId)
          .isFilter('archived_at', null)
          .order('created_at', ascending: false);

      state = AsyncValue.data(
        (data as List).map((r) => AppNotification.fromJson(r)).toList(),
      );

      _channel?.unsubscribe();
      _channel = _db
          .channel('notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              final n = AppNotification.fromJson(payload.newRecord);
              final current = state.value ?? [];
              state = AsyncValue.data([n, ...current]);
            },
          )
          .subscribe();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _db
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      _updateItem(id, (n) => n.copyWith(isRead: true));
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _db
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .isFilter('read_at', null);
      final current = state.value ?? [];
      state = AsyncValue.data(
        current.map((n) => n.copyWith(isRead: true)).toList(),
      );
    } catch (_) {}
  }

  Future<void> archive(String id) async {
    try {
      await _db
          .from('notifications')
          .update({'archived_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      final current = state.value ?? [];
      state = AsyncValue.data(current.where((n) => n.id != id).toList());
    } catch (_) {}
  }

  Future<void> refresh() => _load();

  void _updateItem(String id, AppNotification Function(AppNotification) fn) {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((n) => n.id == id ? fn(n) : n).toList(),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final notificationUnreadCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final db = Supabase.instance.client;
  final userId = db.auth.currentUser?.id;
  if (userId == null) return 0;
  final data = await db
      .from('notifications')
      .select('id')
      .eq('user_id', userId)
      .isFilter('read_at', null)
      .isFilter('archived_at', null);
  return (data as List).length;
});

// ─────────────────────────────────────────────
// NOTIFICATIONS INBOX SCREEN
// ─────────────────────────────────────────────
class NotificationsInboxScreen extends ConsumerStatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  ConsumerState<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState
    extends ConsumerState<NotificationsInboxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_notificationsProvider);
    final notifier = ref.read(_notificationsProvider.notifier);
    final all = async.value ?? [];
    final unread = all.where((n) => !n.isRead).toList();
    final unreadCount = unread.length;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,
        body: Column(
          children: [
            // ── Orange header ──
            _NotifHeader(
              unreadCount: unreadCount,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/student-dashboard'),
              onMarkAll: unreadCount > 0
                  ? () {
                      HapticFeedback.mediumImpact();
                      notifier.markAllRead();
                      _showMarkAllSnack(context);
                    }
                  : null,
              tabCtrl: _tabs,
              unread: unreadCount,
            ),

            // ── Content ──
            Expanded(
              child: async.when(
                loading: () => const NotificationSkeleton(),
                error: (e, _) => _ErrorState(onRetry: notifier.refresh),
                data: (_) => TabBarView(
                  controller: _tabs,
                  children: [
                    _NotifList(
                      items: unread,
                      notifier: notifier,
                      emptyLabel: 'You\'re all caught up!',
                      emptyIcon: Icons.check_circle_outline_rounded,
                      isEmpty: true,
                    ),
                    _NotifList(
                      items: all,
                      notifier: notifier,
                      emptyLabel: 'No notifications yet',
                      emptyIcon: Icons.notifications_none_rounded,
                      isEmpty: false,
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

  void _showMarkAllSnack(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('All notifications marked as read'),
        backgroundColor: DS.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.radiusSm),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATIONS HEADER
// ─────────────────────────────────────────────
class _NotifHeader extends StatelessWidget {
  final int unreadCount, unread;
  final VoidCallback onBack;
  final VoidCallback? onMarkAll;
  final TabController tabCtrl;

  const _NotifHeader({
    required this.unreadCount,
    required this.unread,
    required this.onBack,
    required this.onMarkAll,
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

                      // Title + badge
                      Row(
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: DS.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: DS.s8,
                                vertical: DS.s2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: DS.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const Spacer(),

                      // Mark all read
                      if (onMarkAll != null)
                        GestureDetector(
                          onTap: onMarkAll,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DS.s10,
                              vertical: DS.s6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'Mark all read',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mark_email_unread_outlined,
                            size: 14,
                          ),
                          const SizedBox(width: DS.s6),
                          Text(unread > 0 ? 'Unread ($unread)' : 'Unread'),
                        ],
                      ),
                    ),
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 14),
                          SizedBox(width: DS.s6),
                          Text('All'),
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
// NOTIFICATION LIST (with date grouping)
// ─────────────────────────────────────────────
class _NotifList extends StatelessWidget {
  final List<AppNotification> items;
  final _NotifNotifier notifier;
  final String emptyLabel;
  final IconData emptyIcon;
  final bool isEmpty; // is this the "all caught up" tab?

  const _NotifList({
    required this.items,
    required this.notifier,
    required this.emptyLabel,
    required this.emptyIcon,
    required this.isEmpty,
  });

  // Group notifications by date label
  Map<String, List<AppNotification>> _grouped() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<AppNotification>>{};
    for (final n in items) {
      final d = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      final key = d == today
          ? 'Today'
          : d == yesterday
          ? 'Yesterday'
          : _fmtDate(n.createdAt);
      groups.putIfAbsent(key, () => []).add(n);
    }
    return groups;
  }

  static String _fmtDate(DateTime d) {
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
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyState(
        label: emptyLabel,
        icon: emptyIcon,
        isAllCaughtUp: isEmpty,
      );
    }

    final grouped = _grouped();
    final keys = grouped.keys.toList();

    return RefreshIndicator(
      color: DS.primary,
      onRefresh: () async => notifier.refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(DS.s16, DS.s16, DS.s16, DS.s32),
        itemCount: keys.fold<int>(0, (s, k) => s + 1 + grouped[k]!.length),
        itemBuilder: (_, idx) {
          // Build flat index → (groupKey, itemIndex) map
          int flat = 0;
          for (final key in keys) {
            if (idx == flat) {
              return _DateGroupLabel(label: key);
            }
            flat++;
            final groupItems = grouped[key]!;
            for (int i = 0; i < groupItems.length; i++) {
              if (idx == flat) {
                return _NotifCard(
                  notification: groupItems[i],
                  isLast: i == groupItems.length - 1,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (!groupItems[i].isRead) {
                      notifier.markRead(groupItems[i].id);
                    }
                    final link = groupItems[i].link;
                    if (link != null && link.isNotEmpty) {
                      context.push(link);
                    }
                  },
                  onDismiss: () {
                    HapticFeedback.mediumImpact();
                    notifier.archive(groupItems[i].id);
                  },
                );
              }
              flat++;
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATE GROUP LABEL
// ─────────────────────────────────────────────
class _DateGroupLabel extends StatelessWidget {
  final String label;
  const _DateGroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s10, top: DS.s4),
      child: Row(
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: DS.textPrimary,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(width: DS.s8),
          Expanded(child: Divider(color: DS.border, thickness: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION CARD
// ─────────────────────────────────────────────
class _NotifCard extends StatelessWidget {
  final AppNotification notification;
  final bool isLast;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotifCard({
    required this.notification,
    required this.isLast,
    required this.onTap,
    required this.onDismiss,
  });

  // ── Type → icon / color ──
  IconData get _icon => switch (notification.type) {
    'live' => Icons.sensors_rounded,
    'test' => Icons.quiz_outlined,
    'doubt' => Icons.psychology_outlined,
    'streak' => Icons.local_fire_department_rounded,
    'course' => Icons.menu_book_rounded,
    'payment' => Icons.receipt_long_outlined,
    'result' => Icons.emoji_events_outlined,
    'announcement' => Icons.campaign_rounded,
    _ => Icons.notifications_outlined,
  };

  Color get _color => switch (notification.type) {
    'live' => DS.error,
    'test' => DS.primary,
    'doubt' => DS.indigo,
    'streak' => DS.warning,
    'course' => DS.teal,
    'payment' => DS.success,
    'result' => DS.warning,
    'announcement' => DS.primary,
    _ => DS.textSecondary,
  };

  String get _typeLabel =>
      notification.type[0].toUpperCase() + notification.type.substring(1);

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s10),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: DS.s20),
          decoration: BoxDecoration(
            color: DS.error,
            borderRadius: BorderRadius.circular(DS.radiusMd),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.archive_outlined, color: Colors.white, size: 22),
              SizedBox(height: DS.s4),
              Text(
                'Archive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        onDismissed: (_) => onDismiss(),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(DS.s14),
            decoration: BoxDecoration(
              color: isUnread ? DS.primary.withOpacity(0.04) : DS.surface,
              borderRadius: BorderRadius.circular(DS.radiusMd),
              border: Border.all(
                color: isUnread ? DS.primary.withOpacity(0.20) : DS.border,
                width: isUnread ? 1.4 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon tile ──
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(DS.radiusMd),
                    border: isUnread
                        ? Border.all(color: _color.withOpacity(0.25), width: 1)
                        : null,
                  ),
                  child: Icon(_icon, color: _color, size: 22),
                ),

                const SizedBox(width: DS.s12),

                // ── Content ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + time
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: DS.textPrimary,
                                height: 1.3,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          const SizedBox(width: DS.s8),
                          Text(
                            _ago(notification.createdAt),
                            style: const TextStyle(
                              color: DS.textHint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),

                      // Body
                      if (notification.body != null &&
                          notification.body!.isNotEmpty) ...[
                        const SizedBox(height: DS.s4),
                        Text(
                          notification.body!,
                          style: const TextStyle(
                            color: DS.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: DS.s8),

                      // Footer: type badge + view link + unread dot
                      Row(
                        children: [
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DS.s8,
                              vertical: DS.s3,
                            ),
                            decoration: BoxDecoration(
                              color: _color.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: _color.withOpacity(0.20),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _typeLabel,
                              style: TextStyle(
                                color: _color,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),

                          // View link
                          if (notification.link != null &&
                              notification.link!.isNotEmpty) ...[
                            const SizedBox(width: DS.s8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 11,
                                  color: DS.primary,
                                ),
                                SizedBox(width: DS.s3),
                                Text(
                                  'View',
                                  style: TextStyle(
                                    color: DS.primary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const Spacer(),

                          // Unread dot
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: DS.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'Yesterday';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${(d.inDays / 7).floor()}w ago';
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isAllCaughtUp;

  const _EmptyState({
    required this.label,
    required this.icon,
    required this.isAllCaughtUp,
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: isAllCaughtUp
                    ? const LinearGradient(
                        colors: [DS.success, Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFF8C38), DS.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(DS.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: (isAllCaughtUp ? DS.success : DS.primary)
                        .withOpacity(0.22),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 38),
            ),
            const SizedBox(height: DS.s20),
            Text(
              label,
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
              isAllCaughtUp
                  ? 'You\'ve read all your notifications. Great job!'
                  : 'New notifications will appear here.',
              style: const TextStyle(
                color: DS.textSecondary,
                fontSize: 14,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ERROR STATE
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
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
            const Text(
              'Failed to Load',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s8),
            const Text(
              'Could not load notifications.\nPlease check your connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: DS.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: DS.s24),
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

// Missing DS constant
extension _DSExtra on DS {
  static const double s3 = 3;
}

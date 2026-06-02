import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../auth/data/auth_repository.dart';
import '../profile/data/profile_providers.dart';

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

  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// HOME SHELL
// ─────────────────────────────────────────────
class HomeShell extends ConsumerWidget {
  final Widget child;
  final String location;

  const HomeShell({super.key, required this.child, required this.location});

  static const _tabs = [
    (
      route: '/home',
      iconOff: Icons.home_outlined,
      iconOn: Icons.home_rounded,
      label: 'Home',
    ),
    (
      route: '/courses',
      iconOff: Icons.menu_book_outlined,
      iconOn: Icons.menu_book_rounded,
      label: 'Courses',
    ),
    (
      route: '/compete',
      iconOff: Icons.emoji_events_outlined,
      iconOn: Icons.emoji_events_rounded,
      label: 'Compete',
    ),
    (
      route: '/doubts',
      iconOff: Icons.help_outline_rounded,
      iconOn: Icons.help_rounded,
      label: 'Doubts',
    ),
    (
      route: '/profile',
      iconOff: Icons.person_outline,
      iconOn: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  int get _index => _tabs
      .indexWhere((t) => location.startsWith(t.route))
      .clamp(0, _tabs.length - 1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser();
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final displayName = profile?.fullName?.trim().isNotEmpty == true
        ? profile!.fullName!.trim()
        : (user?.name?.trim().isNotEmpty == true ? user!.name!.trim() : 'Learner');
    final initials = _initials(displayName);
    final currentIdx = _index;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: location == '/home',
        onPopInvoked: (didPop) {
          if (!didPop && location != '/home') {
            context.go('/home');
          }
        },
        child: Scaffold(
          backgroundColor: DS.background,

          // ── Top App Bar ──
          appBar: _AppBar(
            displayName: displayName,
            initials: initials,
            onNotifications: () => context.push('/notifications'),
          ),

          body: child,

          // ── Bottom Navigation ──
          bottomNavigationBar: _BottomNav(
            currentIndex: currentIdx,
            onTap: (i) {
              HapticFeedback.selectionClick();
              context.go(_tabs[i].route);
            },
            tabs: _tabs,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'L';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ─────────────────────────────────────────────
// CUSTOM APP BAR
// ─────────────────────────────────────────────
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final String displayName;
  final String initials;
  final VoidCallback onNotifications;

  const _AppBar({
    required this.displayName,
    required this.initials,
    required this.onNotifications,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

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
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s16,
            vertical: DS.s10,
          ),
          child: Row(
            children: [
              // ── Logo + greeting ──
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
                  boxShadow: [
                    BoxShadow(
                      color: DS.primary.withOpacity(0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),

              const SizedBox(width: DS.s10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: DS.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: DS.textPrimary,
                        letterSpacing: -0.3,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // ── Action buttons ──
              _NotificationButton(onTap: onNotifications),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 🌙';
  }
}

// ─────────────────────────────────────────────
// NOTIFICATION BUTTON (with badge)
// ─────────────────────────────────────────────
class _NotificationButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NotificationButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notifications',
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: DS.surfaceVariant,
                borderRadius: BorderRadius.circular(DS.radiusSm),
                border: Border.all(color: DS.border, width: 1),
              ),
              child: const Icon(
                Icons.notifications_outlined,
                size: 18,
                color: DS.textSecondary,
              ),
            ),
            // Unread dot badge
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: DS.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: DS.surface, width: 1.5),
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
// BOTTOM NAVIGATION BAR
// ─────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  final List<({String route, IconData iconOff, IconData iconOn, String label})>
  tabs;

  const _BottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    const centerIndex = 2; // Compete is the middle tab

    return Container(
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(top: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final tab = tabs[i];
              final isActive = i == currentIndex;

              if (i == centerIndex) {
                // Uplifted center button
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      height: 60,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.topCenter,
                        children: [
                          // Uplifted circle — sits above the bar
                          Positioned(
                            top: -20,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF8C38), DS.primary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: DS.primary.withValues(alpha: 0.40),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: Border.all(color: DS.surface, width: 3),
                              ),
                              child: Icon(
                                isActive ? tab.iconOn : tab.iconOff,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          // Label sits at normal height
                          Positioned(
                            top: 40,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isActive ? DS.primary : DS.textSecondary,
                              ),
                              child: Text(tab.label),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Expanded(
                child: _NavItem(
                  icon: isActive ? tab.iconOn : tab.iconOff,
                  label: tab.label,
                  isActive: isActive,
                  isLive: false,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SINGLE NAV ITEM
// ─────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isLive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.isLive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with active pill indicator
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Active pill background
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: isActive ? 44 : 38,
                height: 32,
                decoration: BoxDecoration(
                  color: isActive ? DS.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(DS.radiusSm),
                ),
              ),

              // Icon
              Icon(
                icon,
                size: 22,
                color: isActive ? DS.primary : DS.textSecondary,
              ),

              // Live pulsing dot
              if (isLive && !isActive)
                Positioned(
                  top: 0,
                  right: 6,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: DS.s4),

          // Label
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? DS.primary : DS.textSecondary,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

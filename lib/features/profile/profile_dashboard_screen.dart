import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../auth/data/auth_repository.dart';
import '../auth/data/student_role_provider.dart';
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

  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFFECFDF5);

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
  static const double s48 = 48;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// PROFILE DASHBOARD SCREEN
// ─────────────────────────────────────────────
class ProfileDashboardScreen extends ConsumerWidget {
  const ProfileDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser();
    final region = ref.watch(regionProvider);
    final prefs = ref.read(prefsProvider);
    final role = ref.watch(studentRoleProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final setupInfo = ref.watch(profileSetupInfoProvider);

    ref.listen<AsyncValue<bool>>(studentRoleProvider, (prev, next) {
      if (next.hasError && (prev == null || !prev.hasError)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't verify your account")),
        );
      }
    });

    // Priority: Supabase profile → prefs (phone-auth setup) → auth metadata
    final String name = profile?.fullName?.trim().isNotEmpty == true
        ? profile!.fullName!.trim()
        : setupInfo.name.isNotEmpty
        ? setupInfo.name
        : (user?.name ?? 'Learner');
    final String email = user?.email ?? '—';
    final String initials = _initials(name);
    final String? avatarUrl = profile?.avatarUrl ?? user?.avatarUrl;
    // Show class + exam from profile setup if available, else fall back to stored goal
    final String goalTag = profile?.targetExam?.isNotEmpty == true
        ? profile!.targetExam!
        : setupInfo.exam.isNotEmpty
        ? setupInfo.exam
        : prefs.goal;
    final String classTag = setupInfo.userClass;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: DS.background,
        body: CustomScrollView(
          slivers: [
            // ── Sticky orange header ──
            SliverPersistentHeader(
              pinned: true,
              delegate: _ProfileHeaderDelegate(
                name: name,
                email: email,
                initials: initials,
                avatarUrl: avatarUrl,
                goal: goalTag,
                classTag: classTag,
                region: region,
                onEdit: () => context.push('/edit-profile'),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                DS.s16,
                DS.s20,
                DS.s16,
                DS.s32,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Dashboard CTA ──
                  if (role.isLoading) ...[
                    _ShimmerCTA(),
                    const SizedBox(height: DS.s20),
                  ] else if (role.value == true || role.hasError) ...[
                    _DashboardCTA(
                      onTap: () => context.push('/student-dashboard'),
                    ),
                    const SizedBox(height: DS.s20),
                  ],

                  // ── Quick links ──
                  _SectionHeader(title: 'Quick Links'),
                  const SizedBox(height: DS.s12),
                  _QuickLinksGrid(context: context),
                  const SizedBox(height: DS.s24),

                  // ── Account options ──
                  _SectionHeader(title: 'Account'),
                  const SizedBox(height: DS.s12),
                  _AccountCard(
                    onSettings: () => context.push('/settings'),
                    onNotifications: () => context.push('/notifications'),
                    onLogout: () async {
                      final confirmed = await _confirmLogout(context);
                      if (!confirmed || !context.mounted) return;
                      await ref.read(authRepositoryProvider).signOut();
                      ref.read(authStateProvider.notifier).refresh();
                      if (context.mounted) context.go('/login');
                    },
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'L';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}

// ─────────────────────────────────────────────
// SLIVER HEADER DELEGATE
// ─────────────────────────────────────────────
class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String name, email, initials, goal, classTag, region;
  final String? avatarUrl;
  final VoidCallback onEdit;

  const _ProfileHeaderDelegate({
    required this.name,
    required this.email,
    required this.initials,
    required this.avatarUrl,
    required this.goal,
    required this.classTag,
    required this.region,
    required this.onEdit,
  });

  @override
  double get minExtent => 90;
  @override
  double get maxExtent => 210;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final progress = (shrinkOffset / maxExtent).clamp(0.0, 1.0);
    final collapsedByScroll = progress > 0.6;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [DS.primaryDark, DS.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(DS.radiusXl),
          bottomRight: Radius.circular(DS.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: DS.primary.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tooShort = constraints.maxHeight < 120;
              final collapsed = collapsedByScroll || tooShort;

              if (tooShort) {
                return Padding(
                  key: const ValueKey('collapsed'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DS.s20,
                    vertical: DS.s16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.40),
                            width: 1.5,
                          ),
                        ),
                        child: _HeaderAvatar(
                          initials: initials,
                          avatarUrl: avatarUrl,
                          size: 40,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: DS.s12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onEdit,
                        child: Container(
                          padding: const EdgeInsets.all(DS.s6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(DS.radiusSm),
                          ),
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: collapsed
                    ? Padding(
                        key: const ValueKey('collapsed'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: DS.s20,
                          vertical: DS.s16,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.40),
                                  width: 1.5,
                                ),
                              ),
                              child: _HeaderAvatar(
                                initials: initials,
                                avatarUrl: avatarUrl,
                                size: 40,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: DS.s12),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: onEdit,
                              child: Container(
                                padding: const EdgeInsets.all(DS.s6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(
                                    DS.radiusSm,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        key: const ValueKey('expanded'),
                        padding: const EdgeInsets.fromLTRB(
                          DS.s20,
                          DS.s12,
                          DS.s16,
                          DS.s20,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.45),
                                  width: 2,
                                ),
                              ),
                              child: _HeaderAvatar(
                                initials: initials,
                                avatarUrl: avatarUrl,
                                size: 68,
                                fontSize: 26,
                              ),
                            ),
                            const SizedBox(width: DS.s16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: DS.s8),
                                  Row(
                                    children: [
                                      if (goal.isNotEmpty) ...[
                                        _Tag(label: goal),
                                        const SizedBox(width: DS.s6),
                                      ],
                                      if (classTag.isNotEmpty)
                                        _Tag(label: classTag)
                                      else
                                        _Tag(
                                          label: region == 'AE'
                                              ? '🇦🇪 Dubai'
                                              : '🇮🇳 India',
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: onEdit,
                              child: Container(
                                padding: const EdgeInsets.all(DS.s8),
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
                                  Icons.edit_outlined,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileHeaderDelegate old) =>
      name != old.name ||
      email != old.email ||
      avatarUrl != old.avatarUrl ||
      goal != old.goal ||
      classTag != old.classTag ||
      region != old.region;
}

class _HeaderAvatar extends StatelessWidget {
  final String initials;
  final String? avatarUrl;
  final double size;
  final double fontSize;
  const _HeaderAvatar({
    required this.initials,
    required this.avatarUrl,
    required this.size,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              initials,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: DS.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: DS.s8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DS.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// TAG CHIP
// ─────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.20),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// DASHBOARD CTA BUTTON
// ─────────────────────────────────────────────
class _DashboardCTA extends StatelessWidget {
  final VoidCallback onTap;
  const _DashboardCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DS.s20,
          vertical: DS.s16,
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
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(DS.s8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(DS.radiusSm),
              ),
              child: const Icon(
                Icons.dashboard_rounded,
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
                    'Student Dashboard',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'View your full learning overview',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerCTA extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    decoration: BoxDecoration(
      color: DS.primaryLight,
      borderRadius: BorderRadius.circular(DS.radiusMd),
    ),
  );
}

// ─────────────────────────────────────────────
// QUICK LINKS GRID
// ─────────────────────────────────────────────
class _QuickLinksGrid extends StatelessWidget {
  final BuildContext context;
  const _QuickLinksGrid({required this.context});

  @override
  Widget build(BuildContext ctx) {
    final links = [
      _QLData(Icons.chat_bubble_outline, 'Mentor Chat', '/mentor-chat'),
      _QLData(Icons.flash_on_outlined, 'Compete', '/compete'),
      _QLData(Icons.insights_outlined, 'My Analytics', '/analytics'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.15,
        crossAxisSpacing: DS.s8,
        mainAxisSpacing: DS.s8,
      ),
      itemCount: links.length,
      itemBuilder: (_, i) => _QuickLinkTile(
        data: links[i],
        onTap: () => context.push(links[i].route),
      ),
    );
  }
}

class _QLData {
  final IconData icon;
  final String label, route;
  const _QLData(this.icon, this.label, this.route);
}

class _QuickLinkTile extends StatelessWidget {
  final _QLData data;
  final VoidCallback onTap;
  const _QuickLinkTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: DS.surface,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          border: Border.all(color: DS.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: DS.primaryLight,
                borderRadius: BorderRadius.circular(DS.radiusSm),
              ),
              child: Icon(data.icon, color: DS.primary, size: 20),
            ),
            const SizedBox(height: DS.s6),
            Text(
              data.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DS.textPrimary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACCOUNT CARD
// ─────────────────────────────────────────────
class _AccountCard extends StatelessWidget {
  final VoidCallback onSettings, onNotifications, onLogout;
  const _AccountCard({
    required this.onSettings,
    required this.onNotifications,
    required this.onLogout,
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
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _AccountTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            color: DS.textSecondary,
            onTap: onSettings,
            showDivider: true,
          ),
          _AccountTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            color: DS.textSecondary,
            onTap: onNotifications,
            showDivider: true,
          ),
          _AccountTile(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: DS.error,
            onTap: onLogout,
            showDivider: false,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showDivider;
  final bool isDestructive;

  const _AccountTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.showDivider,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s16,
              vertical: DS.s14,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDestructive ? DS.errorSurface : DS.surfaceVariant,
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDestructive ? DS.error : DS.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDestructive
                      ? DS.error.withOpacity(0.5)
                      : DS.textHint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: DS.border,
            indent: DS.s16,
            endIndent: DS.s16,
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/error/app_exception.dart';
import '../../core/services/supabase_service.dart';
import 'data/mentor_chat_providers.dart';
import 'data/models/mentor_message.dart';
import 'data/models/mentor_info.dart';

// ignore_for_file: use_build_context_synchronously

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

// ─────────────────────────────────────────────
// REPORT CATEGORIES
// ─────────────────────────────────────────────
const _reportCategories = <String, String>{
  'misconduct': 'Misconduct',
  'inappropriate_content': 'Inappropriate content',
  'no_show': 'Did not show up',
  'payment': 'Payment issue',
  'other': 'Other',
};

// ─────────────────────────────────────────────
// MENTOR CHAT SCREEN
// ─────────────────────────────────────────────
class MentorChatScreen extends ConsumerWidget {
  const MentorChatScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentorAsync = ref.watch(assignedMentorProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: DS.background,

        // ── Custom AppBar ──
        appBar: _ChatAppBar(
          mentorAsync: mentorAsync,
          onReport: (mentor) => _showReportDialog(context, ref, mentor),
          onRate: (mentor) => _showRateDialog(context, ref, mentor),
          onBack: () => context.pop(),
        ),

        body: mentorAsync.when(
          loading: () => const _LoadingState(),
          error: (e, _) => _ErrorState(message: AppException.from(e).userMessage),
          data: (mentor) => mentor == null
              ? const _NoMentorState()
              : _ChatView(mentor: mentor),
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext ctx, WidgetRef ref, MentorInfo mentor) {
    showDialog(
      context: ctx,
      builder: (_) => _ReportMentorDialog(mentor: mentor, ref: ref),
    );
  }

  void _showRateDialog(BuildContext ctx, WidgetRef ref, MentorInfo mentor) {
    showDialog(
      context: ctx,
      builder: (_) => _RateMentorDialog(mentor: mentor, ref: ref),
    );
  }
}

// ─────────────────────────────────────────────
// CUSTOM APP BAR
// ─────────────────────────────────────────────
class _ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final AsyncValue<MentorInfo?> mentorAsync;
  final void Function(MentorInfo) onReport;
  final void Function(MentorInfo) onRate;
  final VoidCallback onBack;

  const _ChatAppBar({
    required this.mentorAsync,
    required this.onReport,
    required this.onRate,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mentor = mentorAsync.valueOrNull;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF8C38), DS.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DS.s8,
            vertical: DS.s10,
          ),
          child: Row(
            children: [
              // Back button
              _AppBarBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
              const SizedBox(width: DS.s8),

              // Title
              const Expanded(
                child: Text(
                  'Mentor Chat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ),

              // Report button
              if (mentor != null) ...[
                _AppBarBtn(
                  icon: Icons.flag_outlined,
                  onTap: () => onReport(mentor),
                  tooltip: 'Report mentor',
                ),
                const SizedBox(width: DS.s6),

                // Rate button — pill style
                GestureDetector(
                  onTap: () => onRate(mentor),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s12,
                      vertical: DS.s8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: Colors.white, size: 14),
                        SizedBox(width: DS.s4),
                        Text(
                          'Rate',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: DS.s8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _AppBarBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(DS.radiusSm),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
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
  Widget build(BuildContext context) => const Center(
    child: CircularProgressIndicator(color: DS.primary, strokeWidth: 2.5),
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: DS.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: DS.error,
                size: 32,
              ),
            ),
            const SizedBox(height: DS.s16),
            Text(
              'Something went wrong',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: DS.textPrimary,
              ),
            ),
            const SizedBox(height: DS.s8),
            Text(
              message,
              style: const TextStyle(fontSize: 13, color: DS.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// NO MENTOR STATE
// ─────────────────────────────────────────────
class _NoMentorState extends StatelessWidget {
  const _NoMentorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DS.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Illustration container
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C38), DS.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: DS.primary.withOpacity(0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: DS.s24),

            const Text(
              'No mentor assigned yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: DS.textPrimary,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DS.s10),
            Text(
              "You'll be matched with a mentor soon.\nCheck back here to start chatting.",
              style: const TextStyle(
                fontSize: 14,
                color: DS.textSecondary,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DS.s28),

            // Info card
            Container(
              padding: const EdgeInsets.all(DS.s16),
              decoration: BoxDecoration(
                color: DS.primaryLight,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(
                  color: DS.primary.withOpacity(0.20),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: DS.primary,
                    size: 18,
                  ),
                  const SizedBox(width: DS.s10),
                  const Expanded(
                    child: Text(
                      'Mentors are usually assigned within 24 hours of enrollment.',
                      style: TextStyle(
                        color: DS.primary,
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CHAT VIEW
// ─────────────────────────────────────────────
class _ChatView extends ConsumerStatefulWidget {
  final MentorInfo mentor;
  const _ChatView({required this.mentor});

  @override
  ConsumerState<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<_ChatView> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  String get _myId => SupabaseService.client.auth.currentUser?.id ?? '';

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    HapticFeedback.lightImpact();
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await ref
          .read(mentorChatRepositoryProvider)
          .sendDirectMessage(mentorId: widget.mentor.mentorId, content: text);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: DS.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.radiusSm),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      mentorMessagesStreamProvider(widget.mentor.mentorId),
    );

    return Column(
      children: [
        // Mentor info strip
        _MentorHeader(mentor: widget.mentor),

        // Messages area
        Expanded(
          child: messagesAsync.when(
            loading: () => const _LoadingState(),
            error: (e, _) => _ErrorState(message: AppException.from(e).userMessage),
            data: (messages) {
              if (messages.isEmpty) return const _EmptyChat();
              _scrollToBottom();
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                  DS.s16,
                  DS.s16,
                  DS.s16,
                  DS.s8,
                ),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isMe = msg.senderId == _myId;
                  final showDate =
                      i == 0 ||
                      !_sameDay(messages[i - 1].createdAt, msg.createdAt);
                  final showAvatar =
                      !isMe &&
                      (i == messages.length - 1 ||
                          messages[i + 1].senderId != msg.senderId);

                  return Column(
                    children: [
                      if (showDate) _DateDivider(date: msg.createdAt),
                      _MessageBubble(
                        message: msg,
                        isMe: isMe,
                        showAvatar: showAvatar,
                        mentor: widget.mentor,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),

        // Input bar
        _InputBar(controller: _msgCtrl, sending: _sending, onSend: _send),
      ],
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────
// EMPTY CHAT STATE
// ─────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: DS.primaryLight,
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: DS.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: DS.s16),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: DS.textPrimary,
            ),
          ),
          const SizedBox(height: DS.s6),
          Text(
            'Say hello to your mentor 👋',
            style: const TextStyle(fontSize: 13.5, color: DS.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MENTOR HEADER STRIP
// ─────────────────────────────────────────────
class _MentorHeader extends StatelessWidget {
  final MentorInfo mentor;
  const _MentorHeader({required this.mentor});

  @override
  Widget build(BuildContext context) {
    final initials = (mentor.name ?? 'M')
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s12),
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
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: DS.primaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DS.primary.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: mentor.avatarUrl != null && mentor.avatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          mentor.avatarUrl!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: DS.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
              ),
              // Online dot
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: DS.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: DS.surface, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: DS.s12),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mentor.name ?? 'Your Mentor',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: DS.textPrimary,
                  ),
                ),
                const SizedBox(height: DS.s2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: DS.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: DS.s4),
                    const Text(
                      'Online · Your Mentor',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: DS.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Info icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DS.surfaceVariant,
              borderRadius: BorderRadius.circular(DS.radiusSm),
              border: Border.all(color: DS.border, width: 1),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: DS.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final MentorMessage message;
  final bool isMe;
  final bool showAvatar;
  final MentorInfo mentor;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
    required this.mentor,
  });

  @override
  Widget build(BuildContext context) {
    final initials = (mentor.name ?? 'M')
        .trim()
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Padding(
      padding: const EdgeInsets.only(bottom: DS.s4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mentor avatar (left side only)
          if (!isMe) ...[
            showAvatar
                ? Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: DS.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: DS.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: 28),
            const SizedBox(width: DS.s6),
          ],

          // Bubble
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.70,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DS.s14,
                vertical: DS.s10,
              ),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFFFF8C38), DS.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : DS.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(DS.radiusMd),
                  topRight: const Radius.circular(DS.radiusMd),
                  bottomLeft: Radius.circular(isMe ? DS.radiusMd : DS.s4),
                  bottomRight: Radius.circular(isMe ? DS.s4 : DS.radiusMd),
                ),
                border: isMe ? null : Border.all(color: DS.border, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: isMe
                        ? DS.primary.withOpacity(0.20)
                        : Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : DS.textPrimary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: DS.s4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.65)
                              : DS.textHint,
                          fontSize: 10,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: DS.s4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 11,
                          color: Colors.white.withOpacity(0.65),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (isMe) const SizedBox(width: DS.s4),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

// ─────────────────────────────────────────────
// DATE DIVIDER
// ─────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final String label;
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      label = 'Today';
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      label = 'Yesterday';
    } else {
      label = '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DS.s16),
      child: Row(
        children: [
          Expanded(child: Divider(color: DS.border, thickness: 1)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: DS.s12),
            padding: const EdgeInsets.symmetric(
              horizontal: DS.s10,
              vertical: DS.s4,
            ),
            decoration: BoxDecoration(
              color: DS.surfaceVariant,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: DS.border, width: 1),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: DS.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: DS.border, thickness: 1)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INPUT BAR
// ─────────────────────────────────────────────
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        DS.s12,
        DS.s10,
        DS.s12,
        DS.s10 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: DS.surface,
        border: Border(top: BorderSide(color: DS.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: DS.surfaceVariant,
                  borderRadius: BorderRadius.circular(DS.radiusXl),
                  border: Border.all(color: DS.border, width: 1.2),
                ),
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14.5, color: DS.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: const TextStyle(
                      color: DS.textSecondary,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: DS.s16,
                      vertical: DS.s12,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
            ),

            const SizedBox(width: DS.s8),

            // Send button
            GestureDetector(
              onTap: sending ? null : onSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: sending
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFFF8C38), DS.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  color: sending ? DS.border : null,
                  shape: BoxShape.circle,
                  boxShadow: sending
                      ? []
                      : [
                          BoxShadow(
                            color: DS.primary.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
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
// RATE MENTOR DIALOG
// ─────────────────────────────────────────────
class _RateMentorDialog extends StatefulWidget {
  final MentorInfo mentor;
  final WidgetRef ref;
  const _RateMentorDialog({required this.mentor, required this.ref});

  @override
  State<_RateMentorDialog> createState() => _RateMentorDialogState();
}

class _RateMentorDialogState extends State<_RateMentorDialog> {
  int _rating = 0;
  final _reviewCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingExisting = true;
  String? _error;
  List<Map<String, dynamic>> _recentReviews = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final repo = widget.ref.read(mentorChatRepositoryProvider);
    final results = await Future.wait([
      repo.fetchMyReview(widget.mentor.mentorId),
      repo.fetchMentorReviews(widget.mentor.mentorId),
    ]);
    final myReview = results[0] as Map<String, dynamic>?;
    final allReviews = results[1] as List<Map<String, dynamic>>;
    if (mounted) {
      setState(() {
        if (myReview != null) {
          _rating = myReview['rating'] as int;
          _reviewCtrl.text = myReview['review'] as String? ?? '';
        }
        _recentReviews = allReviews;
        _loadingExisting = false;
      });
    }
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  double get _averageRating {
    if (_recentReviews.isEmpty) return 0;
    final sum = _recentReviews.fold<int>(0, (s, r) => s + (r['rating'] as int));
    return sum / _recentReviews.length;
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Please select a star rating.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.ref
          .read(mentorChatRepositoryProvider)
          .submitRating(
            mentorId: widget.mentor.mentorId,
            rating: _rating,
            review: _reviewCtrl.text.trim().isEmpty
                ? null
                : _reviewCtrl.text.trim(),
          );
      widget.ref.invalidate(mentorReviewsProvider(widget.mentor.mentorId));
      widget.ref.invalidate(myMentorReviewProvider(widget.mentor.mentorId));
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Review submitted — thank you!'),
            backgroundColor: DS.success,
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
    final mentorName = widget.mentor.name ?? 'your mentor';
    final avg = _averageRating;

    return Dialog(
      backgroundColor: DS.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DS.s20,
        vertical: 40,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DS.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title row ──
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: DS.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: DS.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DS.s12),
                const Expanded(
                  child: Text(
                    'Rate your mentor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: DS.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
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

            const SizedBox(height: DS.s20),

            // ── Info + avg rating card ──
            Container(
              padding: const EdgeInsets.all(DS.s14),
              decoration: BoxDecoration(
                color: DS.background,
                borderRadius: BorderRadius.circular(DS.radiusMd),
                border: Border.all(color: DS.border, width: 1.2),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mentorName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: DS.textPrimary,
                          ),
                        ),
                        const SizedBox(height: DS.s4),
                        Text(
                          'Share how they\'re helping you. Your feedback updates in real time.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: DS.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_loadingExisting && _recentReviews.isNotEmpty) ...[
                    const SizedBox(width: DS.s12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DS.s10,
                        vertical: DS.s8,
                      ),
                      decoration: BoxDecoration(
                        color: DS.warning.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(DS.radiusSm),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: DS.warning,
                                size: 15,
                              ),
                              const SizedBox(width: DS.s4),
                              Text(
                                avg.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: DS.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${_recentReviews.length} review${_recentReviews.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: DS.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: DS.s20),

            // ── Star selector ──
            if (_loadingExisting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: DS.s8),
                  child: CircularProgressIndicator(
                    color: DS.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _rating = i + 1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DS.s6),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          key: ValueKey(filled),
                          color: filled ? DS.warning : DS.textHint,
                          size: 38,
                        ),
                      ),
                    ),
                  );
                }),
              ),

            const SizedBox(height: DS.s20),

            // ── Review text field ──
            _DialogField(
              controller: _reviewCtrl,
              hint: 'Share what\'s working well or what could improve…',
              maxLines: 4,
              maxLength: 500,
            ),

            if (_error != null) ...[
              const SizedBox(height: DS.s8),
              _InlineError(message: _error!),
            ],

            const SizedBox(height: DS.s16),

            // ── Submit ──
            _DialogPrimaryBtn(
              label: _loading ? 'Submitting…' : 'Submit Review',
              loading: _loading || _loadingExisting,
              icon: Icons.send_rounded,
              onTap: _submit,
            ),

            // ── Recent reviews ──
            if (_recentReviews.isNotEmpty) ...[
              const SizedBox(height: DS.s24),
              _SectionDivider(label: 'Recent Feedback'),
              const SizedBox(height: DS.s12),
              ..._recentReviews.take(3).map((r) => _ReviewItem(review: r)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] as int;
    final text = review['review'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: DS.s8),
      padding: const EdgeInsets.all(DS.s12),
      decoration: BoxDecoration(
        color: DS.background,
        borderRadius: BorderRadius.circular(DS.radiusMd),
        border: Border.all(color: DS.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: DS.warning,
                size: 14,
              ),
            ),
          ),
          if (text != null && text.isNotEmpty) ...[
            const SizedBox(height: DS.s6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: DS.textPrimary,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REPORT MENTOR DIALOG
// ─────────────────────────────────────────────
class _ReportMentorDialog extends StatefulWidget {
  final MentorInfo mentor;
  final WidgetRef ref;
  const _ReportMentorDialog({required this.mentor, required this.ref});

  @override
  State<_ReportMentorDialog> createState() => _ReportMentorDialogState();
}

class _ReportMentorDialogState extends State<_ReportMentorDialog> {
  String _category = _reportCategories.keys.first;
  final _subjectCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _evidenceCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _descCtrl.dispose();
    _evidenceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    if (subject.isEmpty || desc.isEmpty) {
      setState(() => _error = 'Please fill in Subject and Description.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.ref
          .read(mentorChatRepositoryProvider)
          .submitReport(
            mentorId: widget.mentor.mentorId,
            mentorName: widget.mentor.name ?? 'Mentor',
            category: _category,
            subject: subject,
            description: desc,
            evidenceUrl: _evidenceCtrl.text.trim().isEmpty
                ? null
                : _evidenceCtrl.text.trim(),
          );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Report submitted. Our team will review it shortly.',
            ),
            backgroundColor: DS.success,
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
    final mentorName = widget.mentor.name ?? 'Mentor';

    return Dialog(
      backgroundColor: DS.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DS.radiusXl),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: DS.s20,
        vertical: 40,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(DS.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title ──
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: DS.errorSurface,
                    borderRadius: BorderRadius.circular(DS.radiusSm),
                  ),
                  child: const Icon(
                    Icons.flag_rounded,
                    color: DS.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: Text(
                    'Report $mentorName',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: DS.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
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

            const SizedBox(height: DS.s20),

            // ── Category ──
            _DialogLabel(label: 'Category'),
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
                  value: _category,
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
                  items: _reportCategories.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
            ),

            const SizedBox(height: DS.s16),

            // ── Subject ──
            _DialogLabel(label: 'Subject'),
            const SizedBox(height: DS.s8),
            _DialogField(
              controller: _subjectCtrl,
              hint: 'Short title of the issue',
            ),

            const SizedBox(height: DS.s16),

            // ── Description ──
            _DialogLabel(label: 'Describe what happened'),
            const SizedBox(height: DS.s8),
            _DialogField(
              controller: _descCtrl,
              hint: 'Add as much detail as possible…',
              maxLines: 5,
            ),

            const SizedBox(height: DS.s16),

            // ── Evidence URL ──
            _DialogLabel(label: 'Evidence link (optional)'),
            const SizedBox(height: DS.s8),
            _DialogField(
              controller: _evidenceCtrl,
              hint: 'https://…',
              keyboardType: TextInputType.url,
            ),

            if (_error != null) ...[
              const SizedBox(height: DS.s10),
              _InlineError(message: _error!),
            ],

            const SizedBox(height: DS.s24),

            // ── Action buttons ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: DS.textPrimary,
                      side: const BorderSide(color: DS.border, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DS.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: DS.s14),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: DS.s12),
                Expanded(
                  child: _DialogPrimaryBtn(
                    label: _loading ? 'Submitting…' : 'Submit Report',
                    loading: _loading,
                    icon: Icons.flag_rounded,
                    color: DS.error,
                    onTap: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED DIALOG WIDGETS
// ─────────────────────────────────────────────
class _DialogLabel extends StatelessWidget {
  final String label;
  const _DialogLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: DS.textPrimary,
    ),
  );
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType keyboardType;

  const _DialogField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14.5, color: DS.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: DS.textHint, fontSize: 14),
        filled: true,
        fillColor: DS.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DS.s14,
          vertical: DS.s12,
        ),
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
        counterStyle: const TextStyle(color: DS.textHint, fontSize: 11),
      ),
    );
  }
}

class _DialogPrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DialogPrimaryBtn({
    required this.label,
    required this.loading,
    required this.icon,
    required this.onTap,
    this.color = DS.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: loading
              ? null
              : LinearGradient(
                  colors: color == DS.primary
                      ? const [Color(0xFFFF8C38), DS.primary]
                      : [color.withOpacity(0.85), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: loading ? DS.border : null,
          borderRadius: BorderRadius.circular(DS.radiusMd),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: color.withOpacity(0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ElevatedButton.icon(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
          ),
          icon: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, size: 16),
          label: Text(
            label,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s12, vertical: DS.s8),
      decoration: BoxDecoration(
        color: DS.errorSurface,
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: DS.error.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: DS.error, size: 15),
          const SizedBox(width: DS.s6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: DS.error, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
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
            fontWeight: FontWeight.w700,
            color: DS.textPrimary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(width: DS.s8),
        const Expanded(child: Divider(color: DS.border, thickness: 1)),
      ],
    );
  }
}

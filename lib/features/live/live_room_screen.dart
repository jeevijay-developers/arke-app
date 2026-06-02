import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';
import '../../core/error/app_exception.dart';
import 'data/live_providers.dart';
import 'data/models/live_class.dart';

// ── Chat message model ─────────────────────────────────────────────────────────

class _ChatMsg {
  final String id;
  final String userId;
  final String displayName;
  final bool isTeacher;
  final String message;
  final DateTime createdAt;

  const _ChatMsg({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.isTeacher,
    required this.message,
    required this.createdAt,
  });

  factory _ChatMsg.fromJson(Map<String, dynamic> j) => _ChatMsg(
        id: j['id'] as String,
        userId: j['user_id'] as String,
        displayName: j['display_name'] as String,
        isTeacher: j['is_teacher'] as bool? ?? false,
        message: j['message'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

// ── Agora token provider ───────────────────────────────────────────────────────

final _agoraTokenProvider =
    FutureProvider.autoDispose.family<String, String>((ref, channelName) async {
  final client = Supabase.instance.client;
  final session = client.auth.currentSession;
  if (session == null) throw Exception('Not authenticated');

  final res = await client.functions.invoke(
    'agora-token',
    body: {'channelName': channelName, 'uid': 0, 'role': 'subscriber'},
    headers: {'Authorization': 'Bearer ${session.accessToken}'},
  );
  if (res.data == null) throw Exception('No response from agora-token');
  final token = (res.data as Map<String, dynamic>)['token'] as String?;
  if (token == null) {
    final err = (res.data as Map<String, dynamic>)['error'];
    throw Exception(err ?? 'Token generation failed');
  }
  return token;
});

// ── Screen ─────────────────────────────────────────────────────────────────────

/// Watches liveClassByIdProvider AND subscribes to Realtime so when the
/// teacher flips status → 'live', the UI upgrades automatically.
class LiveRoomScreen extends ConsumerStatefulWidget {
  final String classId;
  const LiveRoomScreen({super.key, required this.classId});

  @override
  ConsumerState<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends ConsumerState<LiveRoomScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    _channel = client
        .channel('live_class_${widget.classId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'live_classes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.classId,
          ),
          callback: (payload) {
            // Any update (status change) — re-fetch the class
            if (mounted) {
              ref.invalidate(liveClassByIdProvider(widget.classId));
            }
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(liveClassByIdProvider(widget.classId));

    return async.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1))),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/live'),
          ),
          title: const Text('Live Class',
              style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            const Text('Failed to load class',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () =>
                  ref.invalidate(liveClassByIdProvider(widget.classId)),
              child: const Text('Retry'),
            ),
          ]),
        ),
      ),
      data: (lc) {
        if (lc == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Live Class')),
            body: const Center(child: Text('Class not found')),
          );
        }
        return _LiveRoomBody(lc: lc);
      },
    );
  }
}

// ── Room body — decides between waiting room and Agora stream ─────────────────

class _LiveRoomBody extends ConsumerWidget {
  final LiveClass lc;
  const _LiveRoomBody({required this.lc});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelName = lc.id;
    final isLive = lc.isLive;

    if (!isLive) {
      return _WaitingRoom(lc: lc);
    }

    final tokenAsync = ref.watch(_agoraTokenProvider(channelName));
    return tokenAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF0A0A0F),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF6366F1)),
              SizedBox(height: 16),
              Text('Connecting to live class…',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
      ),
      error: (e, _) => _WaitingRoom(lc: lc, tokenError: AppException.from(e).userMessage),
      data: (token) => _AgoraViewer(
        lc: lc,
        channelName: channelName,
        token: token,
      ),
    );
  }
}

// ── Waiting room ───────────────────────────────────────────────────────────────

class _WaitingRoom extends StatelessWidget {
  final LiveClass lc;
  final String? tokenError;
  const _WaitingRoom({required this.lc, this.tokenError});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = lc.startsAt.toLocal().difference(now);
    final timeStr = diff.isNegative
        ? 'shortly'
        : diff.inMinutes < 60
            ? 'in ${diff.inMinutes} min'
            : diff.inHours < 24
                ? 'in ${diff.inHours}h ${diff.inMinutes % 60}m'
                : 'on ${lc.startsAt.toLocal().day}/${lc.startsAt.toLocal().month}';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Stack(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.3),
                radius: 1.2,
                colors: [Color(0xFF1A1035), Color(0xFF0A0A0F)],
              ),
            ),
          ),
          SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white),
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/live'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(lc.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PulseWidget(
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.15),
                                border: Border.all(
                                    color: const Color(0xFF6366F1)
                                        .withValues(alpha: 0.4),
                                    width: 1.5),
                              ),
                              child: const Icon(Icons.sensors_rounded,
                                  color: Color(0xFF818CF8), size: 44),
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (tokenError != null) ...[
                            const Text('Could not connect',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            Text(tokenError!,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 13),
                                textAlign: TextAlign.center),
                          ] else ...[
                            const Text('Class is not live yet.',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            Text(
                              'This class starts $timeStr.\nYou\'ll automatically join when the teacher goes live.',
                              style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 13.5,
                                  height: 1.6),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Column(children: [
                              _InfoTile(
                                  icon: Icons.menu_book_rounded,
                                  label: lc.subject),
                              const SizedBox(height: 10),
                              _InfoTile(
                                  icon: Icons.person_rounded,
                                  label: lc.educatorName),
                              const SizedBox(height: 10),
                              _InfoTile(
                                  icon: Icons.schedule_rounded,
                                  label: _fmtDateTime(lc.startsAt.toLocal())),
                            ]),
                          ),
                        ]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/live'),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: const Text('Back to Classes'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _fmtDateTime(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]}, $h:$m';
  }
}

// ── Agora viewer ───────────────────────────────────────────────────────────────

class _AgoraViewer extends StatefulWidget {
  final LiveClass lc;
  final String channelName;
  final String token;
  const _AgoraViewer({
    required this.lc,
    required this.channelName,
    required this.token,
  });

  @override
  State<_AgoraViewer> createState() => _AgoraViewerState();
}

class _AgoraViewerState extends State<_AgoraViewer> {
  RtcEngine? _engine;
  bool _engineReady = false;
  bool _joined = false;
  int? _remoteUid;

  bool _showControls = true;
  bool _audioMuted = false;
  Timer? _hideTimer;
  String? _errorMsg;

  // ── Chat state ──
  bool _chatOpen = false;
  final List<_ChatMsg> _messages = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  RealtimeChannel? _chatChannel;
  bool _sending = false;
  String? _myDisplayName;

  @override
  void initState() {
    super.initState();
    _init();
    _loadDisplayName();
    _subscribeChat();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    _chatCtrl.dispose();
    _chatScroll.dispose();
    _chatChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadDisplayName() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    final row = await client
        .from('profiles')
        .select('full_name')
        .eq('user_id', uid)
        .maybeSingle();
    if (mounted) {
      setState(() => _myDisplayName =
          (row?['full_name'] as String?)?.trim().isNotEmpty == true
              ? row!['full_name'] as String
              : client.auth.currentUser?.email ?? 'Student');
    }
  }

  void _subscribeChat() {
    final client = Supabase.instance.client;
    // Load recent messages first
    client
        .from('live_class_messages')
        .select()
        .eq('class_id', widget.lc.id)
        .order('created_at')
        .limit(100)
        .then((data) {
      if (!mounted) return;
      setState(() {
        _messages.addAll(
            (data as List).map((r) => _ChatMsg.fromJson(r as Map<String, dynamic>)));
      });
      _scrollToBottom();
    });

    _chatChannel = client
        .channel('chat_${widget.lc.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'live_class_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'class_id',
            value: widget.lc.id,
          ),
          callback: (payload) {
            if (!mounted) return;
            final msg = _ChatMsg.fromJson(payload.newRecord);
            setState(() => _messages.add(msg));
            _scrollToBottom();
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;

    setState(() => _sending = true);
    _chatCtrl.clear();
    try {
      await client.from('live_class_messages').insert({
        'class_id': widget.lc.id,
        'user_id': uid,
        'display_name': _myDisplayName ?? 'Student',
        'is_teacher': false,
        'message': text,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _init() async {
    try {
      await [Permission.microphone, Permission.camera].request();

      final engine = createAgoraRtcEngine();
      _engine = engine;

      await engine.initialize(RtcEngineContext(
        appId: Env.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // Enable video BEFORE setting role and registering handlers
      await engine.enableVideo();
      await engine.enableAudio();

      engine.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('[Agora] onJoinChannelSuccess');
          if (mounted) setState(() => _joined = true);
          _scheduleHideControls();
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('[Agora] onUserJoined uid=$remoteUid');
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onFirstRemoteVideoFrame: (connection, remoteUid, width, height, elapsed) {
          debugPrint('[Agora] onFirstRemoteVideoFrame uid=$remoteUid ${width}x$height');
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onFirstRemoteVideoDecoded: (connection, remoteUid, width, height, elapsed) {
          debugPrint('[Agora] onFirstRemoteVideoDecoded uid=$remoteUid ${width}x$height');
          if (mounted) setState(() => _remoteUid = remoteUid);
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          debugPrint('[Agora] onRemoteVideoStateChanged uid=$remoteUid state=$state reason=$reason');
          if (!mounted) return;
          if (state == RemoteVideoState.remoteVideoStateDecoding ||
              state == RemoteVideoState.remoteVideoStateStarting) {
            setState(() => _remoteUid = remoteUid);
          } else if (state == RemoteVideoState.remoteVideoStateStopped ||
              state == RemoteVideoState.remoteVideoStateFailed) {
            if (_remoteUid == remoteUid) setState(() => _remoteUid = null);
          }
        },
        onRemoteAudioStateChanged: (connection, remoteUid, state, reason, elapsed) {
          debugPrint('[Agora] onRemoteAudioStateChanged uid=$remoteUid state=$state');
          if (!mounted) return;
          if ((state == RemoteAudioState.remoteAudioStateDecoding ||
                  state == RemoteAudioState.remoteAudioStateStarting) &&
              _remoteUid == null) {
            setState(() => _remoteUid = remoteUid);
          }
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('[Agora] onUserOffline uid=$remoteUid reason=$reason');
          if (mounted && _remoteUid == remoteUid) setState(() => _remoteUid = null);
        },
        onError: (err, msg) {
          debugPrint('[Agora] error $err: $msg');
          if (mounted) setState(() => _errorMsg = 'Connection error. Please check your internet and try again.');
        },
      ));

      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicHighQuality,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );
      await engine.setDefaultAudioRouteToSpeakerphone(true);

      // Signal engine is ready so AgoraVideoView can be built BEFORE joining,
      // ensuring the native view surface exists when the first frame arrives.
      if (mounted) setState(() => _engineReady = true);

      await engine.joinChannel(
        token: widget.token,
        channelId: widget.channelName,
        uid: 0,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          audienceLatencyLevel:
              AudienceLatencyLevelType.audienceLatencyLevelLowLatency,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _errorMsg = AppException.from(e).userMessage);
    }
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHideControls();
  }

  void _toggleAudio() async {
    final newMuted = !_audioMuted;
    setState(() => _audioMuted = newMuted);
    await _engine?.muteAllRemoteAudioStreams(newMuted);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTap: () {
            if (_chatOpen) return;
            _toggleControls();
          },
          behavior: HitTestBehavior.opaque,
          child: Stack(children: [
            // ── Video layer ──
            if (_engineReady && _engine != null && _remoteUid != null)
              SizedBox.expand(
                key: ValueKey(_remoteUid),
                child: AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(
                      uid: _remoteUid!,
                      renderMode: RenderModeType.renderModeFit,
                      mirrorMode: VideoMirrorModeType.videoMirrorModeDisabled,
                    ),
                    connection: RtcConnection(channelId: widget.channelName),
                  ),
                ),
              ),

            // ── Waiting / error overlay ──
            if (_errorMsg != null)
              _buildErrorOverlay()
            else if (_remoteUid == null)
              _buildWaitingOverlay(),

            // ── Top gradient + bar ──
            AnimatedOpacity(
              opacity: _showControls && !_chatOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_showControls || _chatOpen,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Colors.transparent],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go('/live'),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.lc.title,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14),
                                    overflow: TextOverflow.ellipsis),
                                Text(widget.lc.educatorName,
                                    style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11.5)),
                              ]),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    color: Colors.white, size: 6),
                                SizedBox(width: 4),
                                Text('LIVE',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800)),
                              ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom controls ──
            if (!_chatOpen)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xCC000000), Colors.transparent],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ControlBtn(
                              icon: _audioMuted
                                  ? Icons.volume_off_rounded
                                  : Icons.volume_up_rounded,
                              label: _audioMuted ? 'Unmute' : 'Mute',
                              onTap: _toggleAudio,
                            ),
                            const SizedBox(width: 24),
                            _ControlBtn(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: 'Chat',
                              onTap: () {
                                setState(() => _chatOpen = true);
                                _scrollToBottom();
                              },
                            ),
                            const SizedBox(width: 24),
                            _ControlBtn(
                              icon: Icons.call_end_rounded,
                              label: 'Leave',
                              color: const Color(0xFFEF4444),
                              onTap: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/live'),
                            ),
                          ]),
                    ),
                  ),
                ),
              ),

            // ── Chat panel ──
            if (_chatOpen) _buildChatPanel(context),
          ]),
        ),
      ),
    );
  }

  Widget _buildChatPanel(BuildContext context) {
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    return Container(
      color: const Color(0xE6000000),
      child: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white),
                onPressed: () => setState(() => _chatOpen = false),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text('Live Chat',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, color: Colors.white, size: 6),
                  SizedBox(width: 4),
                  Text('LIVE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),
          ),
          const Divider(color: Colors.white12, height: 1),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text('No messages yet.\nBe the first to say hi!',
                        style:
                            TextStyle(color: Colors.white38, fontSize: 13),
                        textAlign: TextAlign.center))
                : ListView.builder(
                    controller: _chatScroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isMe = msg.userId == myUid;
                      return _ChatBubble(
                          msg: msg, isMe: isMe);
                    },
                  ),
          ),

          // Input
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            padding: EdgeInsets.fromLTRB(
                12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle:
                        const TextStyle(color: Colors.white38, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildWaitingOverlay() {
    final msg = !_engineReady
        ? 'Joining channel…'
        : _joined
            ? 'Connected — waiting for teacher\'s video…'
            : 'Connecting…';
    return Container(
      color: const Color(0xFF0A0A0F),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(
              color: Color(0xFF6366F1), strokeWidth: 2),
          const SizedBox(height: 20),
          Text(msg,
              style: const TextStyle(color: Colors.white60, fontSize: 14)),
          const SizedBox(height: 8),
          // Debug: show exact channel name being used
          Text(
            'Channel: ${widget.channelName}',
            style: const TextStyle(color: Colors.white24, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          if (_joined && _remoteUid == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Teacher is in a different channel.\nCheck channel name matches admin app.',
              style: TextStyle(color: Colors.white30, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: const Color(0xFF0A0A0F),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            const Text('Connection error',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_errorMsg ?? '',
                style:
                    const TextStyle(color: Colors.white38, fontSize: 12.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                setState(() {
                  _errorMsg = null;
                  _engineReady = false;
                  _joined = false;
                  _remoteUid = null;
                });
                _init();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        color: Color(0xFF818CF8),
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Info tile ──────────────────────────────────────────────────────────────────

// ── Chat bubble ───────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  final _ChatMsg msg;
  final bool isMe;
  const _ChatBubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: msg.isTeacher
                  ? const Color(0xFF6366F1)
                  : Colors.white.withValues(alpha: 0.15),
              child: Text(
                msg.displayName.isNotEmpty
                    ? msg.displayName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(msg.displayName,
                          style: TextStyle(
                              color: msg.isTeacher
                                  ? const Color(0xFF818CF8)
                                  : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      if (msg.isTeacher) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Teacher',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF6366F1)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Text(msg.message,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info tile ──────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 15, color: Colors.white38),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ]);
}

// ── Control button ─────────────────────────────────────────────────────────────

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ControlBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(
                  color: color.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

// ── Pulse animation ────────────────────────────────────────────────────────────

class _PulseWidget extends StatefulWidget {
  final Widget child;
  const _PulseWidget({required this.child});

  @override
  State<_PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<_PulseWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

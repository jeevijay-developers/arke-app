import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const success = Color(0xFF10B981);
  static const successSurface = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);

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
  static const double s48 = 48;

  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
}

// ─────────────────────────────────────────────
// COMPETE COUNTDOWN WIDGET
// ─────────────────────────────────────────────
class CompeteCountdownWidget extends StatefulWidget {
  final CompeteMatch match;
  final String userId;
  final VoidCallback onCountdownDone;

  const CompeteCountdownWidget({
    super.key,
    required this.match,
    required this.userId,
    required this.onCountdownDone,
  });

  @override
  State<CompeteCountdownWidget> createState() => _CompeteCountdownWidgetState();
}

class _CompeteCountdownWidgetState extends State<CompeteCountdownWidget>
    with TickerProviderStateMixin {
  int _secondsLeft = 5;
  bool _showGo = false;
  bool _fired = false;
  Timer? _timer;

  // Pulse animation — ⚔️ swords
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Number pop animation — each new digit
  late AnimationController _numCtrl;
  late Animation<double> _numScale;

  // Progress ring animation
  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();

    // ── Pulse ──
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.88,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // ── Number pop ──
    _numCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _numScale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _numCtrl, curve: Curves.elasticOut));

    // ── Progress ring — sweeps from full to empty over 5 seconds ──
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();

    _computeAndStart();
  }

  void _computeAndStart() {
    final until = widget.match.countdownUntil;
    if (until != null) {
      final rem = until.difference(DateTime.now()).inSeconds;
      _secondsLeft = rem.clamp(0, 5);
    } else {
      _secondsLeft = 5;
    }

    if (_secondsLeft <= 0) {
      _triggerDone();
      return;
    }

    _numCtrl.forward(from: 0);

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      final until = widget.match.countdownUntil;
      final left = until != null
          ? until.difference(DateTime.now()).inSeconds.clamp(0, 5)
          : _secondsLeft - 1;

      if (left <= 0) {
        t.cancel();
        if (mounted) {
          HapticFeedback.heavyImpact();
          setState(() {
            _secondsLeft = 0;
            _showGo = true;
          });
          _numCtrl.forward(from: 0);
          Future.delayed(const Duration(milliseconds: 800), _triggerDone);
        }
        return;
      }

      if (mounted) {
        HapticFeedback.lightImpact();
        setState(() => _secondsLeft = left);
        _numCtrl.forward(from: 0);
      }
    });
  }

  void _triggerDone() {
    if (_fired) return;
    _fired = true;
    if (mounted) widget.onCountdownDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _numCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  bool get _imP1 => widget.match.player1Id == widget.userId;
  String get _myName => _imP1
      ? (widget.match.player1Name ?? 'You')
      : (widget.match.player2Name ?? 'You');
  String get _oppName => _imP1
      ? (widget.match.player2Name ?? (_isBot ? 'AI Opponent' : 'Opponent'))
      : (widget.match.player1Name ?? 'Opponent');
  bool get _isBot => widget.match.isBot;
  String? get _myAvatar =>
      _imP1 ? widget.match.player1Avatar : widget.match.player2Avatar;
  String? get _oppAvatar =>
      _imP1 ? widget.match.player2Avatar : widget.match.player1Avatar;

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  // Countdown color shifts: 5→3 orange, 2→1 warning, GO! green
  Color get _countColor => _showGo
      ? DS.success
      : _secondsLeft <= 2
      ? DS.warning
      : Colors.white;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Full-screen orange gradient ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF8C38), DS.primary, DS.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),

            // ── Decorative circles ──
            Positioned(
              top: -80,
              left: -60,
              child: _Circle(size: 220, opacity: 0.10),
            ),
            Positioned(
              top: 80,
              right: -40,
              child: _Circle(size: 140, opacity: 0.08),
            ),
            Positioned(
              bottom: 60,
              left: -40,
              child: _Circle(size: 160, opacity: 0.08),
            ),
            Positioned(
              bottom: -60,
              right: -60,
              child: _Circle(size: 200, opacity: 0.10),
            ),

            // ── Main content ──
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: DS.s24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Match Found badge ──
                      _MatchFoundBadge(),
                      const SizedBox(height: DS.s32),

                      // ── Avatar row ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PlayerAvatar(
                            name: _myName,
                            initials: _initials(_myName),
                            avatarUrl: _myAvatar,
                            label: 'READY',
                            isBot: false,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DS.s20,
                            ),
                            child: ScaleTransition(
                              scale: _pulseAnim,
                              child: const Text(
                                '⚔️',
                                style: TextStyle(fontSize: 34),
                              ),
                            ),
                          ),
                          _PlayerAvatar(
                            name: _oppName,
                            initials: _initials(_oppName),
                            avatarUrl: _oppAvatar,
                            label: _isBot ? 'BOT' : 'READY',
                            isBot: _isBot,
                          ),
                        ],
                      ),
                      const SizedBox(height: DS.s48),

                      // ── Countdown ring + number ──
                      _CountdownRing(
                        ringCtrl: _ringCtrl,
                        numScale: _numScale,
                        secondsLeft: _secondsLeft,
                        showGo: _showGo,
                        countColor: _countColor,
                      ),
                      const SizedBox(height: DS.s48),

                      // ── Match metadata pills ──
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: DS.s8,
                        runSpacing: DS.s8,
                        children: [
                          _MetaPill(widget.match.subject),
                          if (widget.match.topic.isNotEmpty)
                            _MetaPill(widget.match.topic),
                          _MetaPill('${widget.match.totalQuestions} questions'),
                          const _MetaPill('30s each'),
                        ],
                      ),
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
// DECORATIVE CIRCLE
// ─────────────────────────────────────────────
class _Circle extends StatelessWidget {
  final double size, opacity;
  const _Circle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withOpacity(opacity),
    ),
  );
}

// ─────────────────────────────────────────────
// MATCH FOUND BADGE
// ─────────────────────────────────────────────
class _MatchFoundBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: DS.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: DS.s8),
        const Text(
          'Match Found!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// PLAYER AVATAR
// ─────────────────────────────────────────────
class _PlayerAvatar extends StatelessWidget {
  final String name, initials;
  final String? avatarUrl;
  final String label;
  final bool isBot;

  const _PlayerAvatar({
    required this.name,
    required this.initials,
    required this.avatarUrl,
    required this.label,
    required this.isBot,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Avatar circle
      Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.40), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: avatarUrl != null && avatarUrl!.isNotEmpty
              ? Image.network(
                  avatarUrl!,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _InitialsFill(initials: initials),
                )
              : _InitialsFill(initials: initials),
        ),
      ),

      const SizedBox(height: DS.s8),

      // Name
      SizedBox(
        width: 90,
        child: Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      const SizedBox(height: DS.s4),

      // Ready / Bot badge
      Container(
        padding: const EdgeInsets.symmetric(horizontal: DS.s8, vertical: DS.s3),
        decoration: BoxDecoration(
          color: isBot
              ? Colors.white.withOpacity(0.12)
              : DS.success.withOpacity(0.22),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isBot
                ? Colors.white.withOpacity(0.20)
                : DS.success.withOpacity(0.50),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isBot ? Colors.white60 : DS.success,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    ],
  );
}

class _InitialsFill extends StatelessWidget {
  final String initials;
  const _InitialsFill({required this.initials});

  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    height: 76,
    color: Colors.white.withOpacity(0.18),
    child: Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// COUNTDOWN RING + NUMBER
// ─────────────────────────────────────────────
class _CountdownRing extends StatelessWidget {
  final AnimationController ringCtrl;
  final Animation<double> numScale;
  final int secondsLeft;
  final bool showGo;
  final Color countColor;

  const _CountdownRing({
    required this.ringCtrl,
    required this.numScale,
    required this.secondsLeft,
    required this.showGo,
    required this.countColor,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 140,
    height: 140,
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
          ),
        ),

        // Animated progress ring
        AnimatedBuilder(
          animation: ringCtrl,
          builder: (_, __) => SizedBox(
            width: 130,
            height: 130,
            child: CircularProgressIndicator(
              value: 1.0 - ringCtrl.value,
              strokeWidth: 6,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              strokeCap: StrokeCap.round,
            ),
          ),
        ),

        // Countdown number / GO!
        ScaleTransition(
          scale: numScale,
          child: showGo
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GO!',
                      style: TextStyle(
                        color: countColor,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        shadows: [
                          Shadow(
                            color: countColor.withOpacity(0.40),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$secondsLeft',
                      style: TextStyle(
                        color: countColor,
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -3,
                        height: 1.0,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.20),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────
// META PILL
// ─────────────────────────────────────────────
class _MetaPill extends StatelessWidget {
  final String text;
  const _MetaPill(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: DS.s12, vertical: DS.s6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

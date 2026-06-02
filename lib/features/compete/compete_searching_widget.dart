import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CompeteSearchingWidget extends StatefulWidget {
  final String? roomCode;      // null = random matchmaking, non-null = private room
  final VoidCallback onCancel;

  const CompeteSearchingWidget({
    super.key,
    this.roomCode,
    required this.onCancel,
  });

  @override
  State<CompeteSearchingWidget> createState() => _CompeteSearchingWidgetState();
}

class _CompeteSearchingWidgetState extends State<CompeteSearchingWidget>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF0A0A0F);
  static const _primary = Color(0xFF6366F1);
  static const _accent = Color(0xFF8B5CF6);
  static const _green = Color(0xFF10B981);

  late final AnimationController _spinCtrl;
  int _elapsedSec = 0;
  Timer? _ticker;
  bool _showBotOption = false;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSec++;
        if (widget.roomCode == null && _elapsedSec >= 25) {
          _showBotOption = true;
        }
      });
    });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  void _copyCode() {
    if (widget.roomCode == null) return;
    Clipboard.setData(ClipboardData(text: widget.roomCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Code copied!'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gradient spinner
                RotationTransition(
                  turns: _spinCtrl,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [_primary, _accent, Colors.transparent],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: _bg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sports_kabaddi_rounded,
                            color: Colors.white54, size: 26),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                if (widget.roomCode == null) ...[
                  // ── Matchmaking sub-mode ──────────────────────────────
                  const Text(
                    'Searching for opponent...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Time: ${_elapsedSec}s',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  if (_showBotOption) ...[
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        backgroundColor: _accent.withValues(alpha: 0.15),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text(
                        'Play vs Bot instead',
                        style: TextStyle(
                            color: _accent, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ] else ...[
                  // ── Private room sub-mode ─────────────────────────────
                  const Text(
                    'Share this room code with a friend',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Room code display
                  GestureDetector(
                    onTap: _copyCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _green.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.roomCode!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.copy_rounded,
                              color: _green, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Waiting for opponent... ${_elapsedSec}s',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 40),
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

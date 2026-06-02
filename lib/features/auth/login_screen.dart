import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/error/app_exception.dart';
import 'data/auth_repository.dart';
import 'widgets/google_email_sheet.dart';

// ─────────────────────────────────────────────
// 🎨  APP DESIGN SYSTEM — use these tokens on
//     every screen for a consistent look.
// ─────────────────────────────────────────────
abstract class DS {
  // Brand
  static const primary = Color(0xFFF97315);
  static const primaryLight = Color(0xFFFFF0E6);
  static const primaryDark = Color(0xFFE05A00);

  // Surfaces
  static const background = Color(0xFFFFFBF8); // warm off-white
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);

  // Text
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textHint = Color(0xFFD1D5DB);

  // Borders / dividers
  static const border = Color(0xFFE5E7EB);

  // Semantic
  static const error = Color(0xFFEF4444);
  static const errorSurface = Color(0xFFFEF2F2);
  static const success = Color(0xFF10B981);

  // Spacing (8-pt grid)
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;

  // Radius
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;

  // Elevation shadows
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────
// LOGIN SCREEN
// ─────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _form = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  late AnimationController _ctrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _heroFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _cardFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Auth logic (unchanged from original) ──
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: _emailCtrl.text.trim(), password: _passwordCtrl.text);
      ref.read(authStateProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      setState(() => _error = AppException.from(e).userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    final email = await showGoogleEmailSheet(context);
    if (email == null || !mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle(email);
      if (!mounted) return;
      context.push('/verify-otp?email=${Uri.encodeComponent(email)}&source=google');
    } catch (e) {
      setState(() => _error = AppException.from(e).userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.primary,
      body: Stack(
        children: [
          // ── Decorative background shapes ──
          const _HeroDecorations(),

          Column(
            children: [
              // ── Hero / Branding section ──
              Expanded(
                flex: 38,
                child: SafeArea(
                  bottom: false,
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: const _HeroSection(),
                  ),
                ),
              ),

              // ── Form card ──
              Expanded(
                flex: 62,
                child: SlideTransition(
                  position: _cardSlide,
                  child: FadeTransition(
                    opacity: _cardFade,
                    child: _FormCard(
                      form: _form,
                      emailCtrl: _emailCtrl,
                      passwordCtrl: _passwordCtrl,
                      loading: _loading,
                      error: _error,
                      obscure: _obscurePassword,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onSubmit: _submit,
                      onGoogle: _googleSignIn,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // ── Help button — top-right corner ──
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: DS.s8, right: DS.s16),
                child: TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse('https://www.arke.pro/contact'),
                    mode: LaunchMode.externalApplication,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s16,
                      vertical: DS.s8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DS.radiusSm),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: const Text(
                    'Help',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HERO DECORATIONS
// ─────────────────────────────────────────────
class _HeroDecorations extends StatelessWidget {
  const _HeroDecorations();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -50,
          child: _Circle(size: 220, opacity: 0.10),
        ),
        Positioned(
          top: 60,
          left: -40,
          child: _Circle(size: 140, opacity: 0.07),
        ),
        Positioned(top: 20, right: 60, child: _Circle(size: 60, opacity: 0.12)),
        Positioned(
          top: 140,
          right: -20,
          child: Transform.rotate(
            angle: math.pi / 6,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.12),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
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
// HERO SECTION
// ─────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DS.s24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo container
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: DS.s20),
          const Text(
            'Welcome Back! 👋',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: DS.s8),
          Text(
            'Sign in to continue your\nlearning journey',
            style: TextStyle(
              fontSize: 14.5,
              color: Colors.white.withOpacity(0.80),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FORM CARD
// ─────────────────────────────────────────────
class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> form;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool loading;
  final bool obscure;
  final String? error;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onGoogle;

  const _FormCard({
    required this.form,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.loading,
    required this.obscure,
    required this.error,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onGoogle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: DS.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(DS.radiusXl),
          topRight: Radius.circular(DS.radiusXl),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(DS.s24, DS.s32, DS.s24, DS.s24),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: DS.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: DS.s12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: DS.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Enter your credentials to proceed',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: DS.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: DS.s24),

              // ── Email field ──
              _AppField(
                controller: emailCtrl,
                label: 'Email Address',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),

              const SizedBox(height: DS.s16),

              // ── Password field ──
              _AppField(
                controller: passwordCtrl,
                label: 'Password',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: obscure,
                validator: (v) =>
                    (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                suffix: GestureDetector(
                  onTap: onToggleObscure,
                  child: Padding(
                    padding: const EdgeInsets.all(DS.s12),
                    child: Icon(
                      obscure
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: DS.textSecondary,
                    ),
                  ),
                ),
              ),

              // ── Forgot password ──
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/forgot'),
                  style: TextButton.styleFrom(
                    foregroundColor: DS.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: DS.s8,
                      vertical: DS.s4,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              // ── Error banner ──
              if (error != null) ...[
                const SizedBox(height: DS.s8),
                _ErrorBanner(message: error!),
                const SizedBox(height: DS.s8),
              ] else
                const SizedBox(height: DS.s4),

              // ── Login button ──
              _PrimaryButton(
                label: 'Login',
                loading: loading,
                onTap: loading ? null : onSubmit,
              ),

              const SizedBox(height: DS.s20),

              // ── Divider ──
              Row(
                children: [
                  Expanded(child: Divider(color: DS.border, thickness: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: DS.s12),
                    child: Text(
                      'or continue with',
                      style: TextStyle(
                        fontSize: 12,
                        color: DS.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: DS.border, thickness: 1)),
                ],
              ),

              const SizedBox(height: DS.s16),

              // ── Google button ──
              _GoogleButton(loading: loading, onTap: loading ? null : onGoogle),

              const SizedBox(height: DS.s24),

              // ── Sign up ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(color: DS.textSecondary, fontSize: 14),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/signup'),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: DS.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Text Field
// ─────────────────────────────────────────────
class _AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _AppField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: DS.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: DS.textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: DS.textHint, fontSize: 14),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: DS.s4),
          child: Icon(icon, size: 20, color: DS.textSecondary),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: DS.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DS.s16,
          vertical: DS.s16,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.radiusMd),
          borderSide: const BorderSide(color: DS.error, width: 1.8),
        ),
        errorStyle: const TextStyle(color: DS.error, fontSize: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Primary Button
// ─────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onTap == null
              ? null
              : const LinearGradient(
                  colors: [Color(0xFFFF8C38), DS.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(DS.radiusMd),
          boxShadow: onTap == null
              ? []
              : [
                  BoxShadow(
                    color: DS.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: DS.border,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DS.radiusMd),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// REUSABLE: Google Button
// ─────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _GoogleButton({required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: DS.surface,
          foregroundColor: DS.textPrimary,
          side: const BorderSide(color: DS.border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DS.radiusMd),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" logo — colored rings
            SizedBox(
              width: 22,
              height: 22,
              child: CustomPaint(painter: _GoogleGPainter()),
            ),
            const SizedBox(width: DS.s12),
            const Text(
              'Continue with Google',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Google G Logo Painter
// ─────────────────────────────────────────────
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.16;

    // Draw colored arc segments (simplified Google G)
    final colors = [
      const Color(0xFF4285F4), // blue   (top)
      const Color(0xFFEA4335), // red    (right)
      const Color(0xFFFBBC05), // yellow (bottom)
      const Color(0xFF34A853), // green  (left)
    ];
    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r - paint.strokeWidth / 2),
        (math.pi / 2) * i - math.pi / 2,
        math.pi / 2 - 0.08,
        false,
        paint,
      );
    }

    // The horizontal bar of "G"
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx, center.dy),
      Offset(size.width - size.width * 0.08, center.dy),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// REUSABLE: Error Banner
// ─────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DS.s16, vertical: DS.s12),
      decoration: BoxDecoration(
        color: DS.errorSurface,
        borderRadius: BorderRadius.circular(DS.radiusSm),
        border: Border.all(color: DS.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: DS.error, size: 18),
          const SizedBox(width: DS.s8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: DS.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

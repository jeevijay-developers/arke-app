import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/primary_button.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  String _region = 'IN';
  String _goal = 'JEE';

  final _slides = const [
    (Icons.auto_stories_rounded, 'Live classes, anytime', 'Join interactive live lectures from India\'s top educators.'),
    (Icons.quiz_rounded, 'Test yourself', 'Immersive mock tests with instant analysis.'),
    (Icons.trending_up_rounded, 'Track your progress', 'Streaks, leaderboards, and AI doubt solving.'),
  ];

  Future<void> _finish() async {
    final prefs = ref.read(prefsProvider);
    await prefs.setOnboardingDone(true);
    await prefs.setRegion(_region);
    await prefs.setGoal(_goal);
    ref.read(regionProvider.notifier).set(_region);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(32)),
                          child: Icon(s.$1, size: 72, color: AppColors.primary),
                        ),
                        const SizedBox(height: 32),
                        Text(s.$2, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Text(s.$3, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8, height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Region', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(children: [
                    _pill('🇮🇳 India', 'IN'),
                    const SizedBox(width: 8),
                    _pill('🇦🇪 Dubai', 'AE'),
                  ]),
                  const SizedBox(height: 16),
                  Text('Your goal', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final g in ['JEE', 'NEET', 'Boards', 'JEE+NEET']) _goalChip(g),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: PrimaryButton(label: 'Continue', onPressed: _finish),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, String value) {
    final sel = _region == value;
    return GestureDetector(
      onTap: () => setState(() => _region = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : AppColors.navy, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _goalChip(String g) {
    final sel = _goal == g;
    return GestureDetector(
      onTap: () => setState(() => _goal = g),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(g, style: TextStyle(color: sel ? Colors.white : AppColors.navy, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

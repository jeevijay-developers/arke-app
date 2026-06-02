import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class ComingSoonScreen extends StatelessWidget {
  final String title;
  const ComingSoonScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.rocket_launch_outlined, size: 96, color: AppColors.primary),
            const SizedBox(height: 16),
            Text('$title — coming soon', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('We\'re polishing this experience. Stay tuned!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}

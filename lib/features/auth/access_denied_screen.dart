import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';

class AccessDeniedScreen extends StatelessWidget {
  final String title;
  final String message;
  final String primaryCtaLabel;
  final String primaryCtaRoute;

  const AccessDeniedScreen({
    super.key,
    this.title = 'Access denied',
    this.message = 'This area is only available to students.',
    this.primaryCtaLabel = 'Go to Profile',
    this.primaryCtaRoute = '/profile',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access denied')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go(primaryCtaRoute),
                child: Text(primaryCtaLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

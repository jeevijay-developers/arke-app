import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/student_role_provider.dart';
import '../access_denied_screen.dart';

class StudentGate extends ConsumerWidget {
  final Widget child;
  const StudentGate({required this.child, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(studentRoleProvider);
    return role.when(
      data: (isStudent) => isStudent
          ? child
          : const AccessDeniedScreen(
              message: 'Only students can open the dashboard.',
            ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const AccessDeniedScreen(
        message: 'Could not verify your account. Please try again.',
      ),
    );
  }
}

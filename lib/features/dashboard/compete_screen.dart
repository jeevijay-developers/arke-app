import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../compete/compete_screen_v2.dart';

// Entry point for the /compete route.
// Delegates entirely to CompeteScreenV2 which owns the full phase state machine.
class CompeteScreen extends ConsumerWidget {
  const CompeteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const CompeteScreenV2();
  }
}

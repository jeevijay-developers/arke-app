import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client.dart';
import 'auth_repository.dart';

final studentRoleProvider = FutureProvider<bool>((ref) async {
  ref.watch(authStateProvider);
  final user = ref.watch(authRepositoryProvider).currentUser();
  if (user == null) return false;

  final sb = supabaseOrNull;
  if (sb == null) {
    return true;
  }

  try {
    final data = await sb
        .from('user_roles')
        .select('role')
        .eq('user_id', user.id)
        .maybeSingle();
    if (data == null) return true;
    final role = data['role'] as String?;
    if (role == null) return true;
    return role == 'student';
  } catch (_) {
    return false;
  }
});

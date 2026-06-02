import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage/preferences.dart';

final prefsProvider = Provider<Prefs>((ref) => throw UnimplementedError('override in main'));

class RegionNotifier extends StateNotifier<String> {
  final Prefs _prefs;
  RegionNotifier(this._prefs) : super(_prefs.region);
  Future<void> set(String v) async {
    await _prefs.setRegion(v);
    state = v;
  }
}

final regionProvider = StateNotifierProvider<RegionNotifier, String>(
  (ref) => RegionNotifier(ref.watch(prefsProvider)),
);

// True while the forgot-password OTP→reset flow is active.
// Prevents auth-state change (from verifyOTP) redirecting to /home.
final passwordResetInProgressProvider = StateProvider<bool>((ref) => false);

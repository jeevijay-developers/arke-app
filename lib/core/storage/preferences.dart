import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static const _kOnboardingDone = 'onboarding_done';
  static const _kRegion = 'arke-country';
  static const _kGoal = 'arke-goal';

  final SharedPreferences _p;
  Prefs(this._p);

  static Future<Prefs> create() async => Prefs(await SharedPreferences.getInstance());

  bool get onboardingDone => _p.getBool(_kOnboardingDone) ?? false;
  Future<void> setOnboardingDone(bool v) => _p.setBool(_kOnboardingDone, v);

  String get region => _p.getString(_kRegion) ?? 'IN';
  Future<void> setRegion(String v) => _p.setString(_kRegion, v);

  String get goal => _p.getString(_kGoal) ?? 'JEE';
  Future<void> setGoal(String v) => _p.setString(_kGoal, v);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase/supabase_client.dart';


class AuthUser {
  final String id;
  final String? email;
  final String? name;
  final String? avatarUrl;
  const AuthUser({required this.id, this.email, this.name, this.avatarUrl});
}

class AuthRepository {
  User? get _user => supabaseOrNull?.auth.currentUser;

  bool get isSignedIn => _user != null || _mockUser != null;

  AuthUser? _mockUser;

  // Temporarily holds the password chosen on signup form until OTP is verified
  // and updatePassword() is called from ResetPasswordScreen.
  String? pendingPassword;

  AuthUser? currentUser() {
    if (_user != null) {
      return AuthUser(
        id: _user!.id,
        email: _user!.email,
        name: _user!.userMetadata?['full_name'] as String?,
        avatarUrl: _user!.userMetadata?['avatar_url'] as String?,
      );
    }
    return _mockUser;
  }

  // ── Email + password login (existing accounts) ──────────────────────────
  Future<void> signIn({required String email, required String password}) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.signInWithPassword(email: email, password: password);
    } else {
      _mockUser = AuthUser(
        id: 'mock-${email.hashCode}',
        email: email,
        name: email.split('@').first,
      );
    }
  }

  // ── Email signup — sends OTP for verification ───────────────────────────
  // Stores user metadata and sends a 6-digit OTP via signInWithOtp.
  // After OTP is verified in OtpVerificationScreen, the user is signed in
  // and then redirected to ResetPasswordScreen to set their password.
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    String region = 'IN',
  }) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        data: {
          'full_name': name,
          'phone': phone ?? '',
          'region': region,
        },
      );
    } else {
      _mockUser = AuthUser(
        id: 'mock-${email.hashCode}',
        email: email,
        name: name,
      );
    }
  }

  // ── "Continue with Google" — sends 6-digit OTP to Gmail ─────────────────
  Future<void> signInWithGoogle(String email) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
    } else {
      _mockUser = AuthUser(
        id: 'mock-${email.hashCode}',
        email: email,
        name: email.split('@').first,
      );
    }
  }

  // ── Verify 6-digit OTP entered by the user ───────────────────────────────
  Future<void> verifyOtp({
    required String email,
    required String token,
    bool isGoogleFlow = false,
  }) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );
    } else {
      _mockUser = AuthUser(
        id: 'mock-${email.hashCode}',
        email: email,
        name: email.split('@').first,
      );
    }
  }

  // ── Resend OTP ───────────────────────────────────────────────────────────
  Future<void> resendOtp({
    required String email,
    bool isGoogleFlow = false,
  }) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
    }
  }

  // ── Forgot password — sends 6-digit OTP via recovery email ─────────────
  Future<void> sendPasswordResetOtp(String email) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.signInWithOtp(
        email: email,
        shouldCreateUser: false,
      );
    }
  }

  // ── Verify recovery OTP ──────────────────────────────────────────────────
  // Uses OtpType.magiclink because sendPasswordResetOtp calls signInWithOtp
  // which generates a magiclink-type token, not a signup-type token.
  Future<void> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.magiclink,
      );
    } else {
      _mockUser = AuthUser(
        id: 'mock-${email.hashCode}',
        email: email,
        name: email.split('@').first,
      );
    }
  }

  // ── Update password after OTP verified ──────────────────────────────────
  Future<void> updatePassword(String newPassword) async {
    final sb = supabaseOrNull;
    if (sb != null) {
      await sb.auth.updateUser(UserAttributes(password: newPassword));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    final sb = supabaseOrNull;
    if (sb != null) await sb.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    _mockUser = null;
    await supabaseOrNull?.auth.signOut();
  }

  Stream<bool> authChanges() {
    final sb = supabaseOrNull;
    if (sb != null) {
      return sb.auth.onAuthStateChange.map((_) => sb.auth.currentUser != null);
    }
    return const Stream.empty();
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, bool>((ref) {
  return AuthStateNotifier(ref.watch(authRepositoryProvider));
});

class AuthStateNotifier extends StateNotifier<bool> {
  final AuthRepository _repo;
  AuthStateNotifier(this._repo) : super(_repo.isSignedIn) {
    _repo.authChanges().listen((v) => state = v);
  }
  void refresh() => state = _repo.isSignedIn;
}

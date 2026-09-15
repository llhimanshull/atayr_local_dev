import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Returns the current user
  User? get currentUser => _client.auth.currentUser;

  /// Exposes the auth state change stream
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up with email and password
  Future<AuthResponse> signUp({required String email, required String password}) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({required String email, required String password}) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Sign in with Google (OAuth web flow)
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.atayr.atayr://login-callback',
    );
  }
}

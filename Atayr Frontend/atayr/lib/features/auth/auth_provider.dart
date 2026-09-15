import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;

  bool _isLoading = false;
  String? _errorMessage;
  User? _user;

  AuthProvider(this._authService) {
    _init();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get user => _user;
  bool get isAuthenticated => _user != null;

  void _init() {
    // Initial user fetch
    _user = _authService.currentUser;
    notifyListeners();

    // Listen to session changes
    _authService.authStateChanges.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    _setError(null);
  }

  Future<bool> signIn(String email, String password) async {
    _setLoading(true);
    clearError();
    try {
      await _authService.signIn(email: email, password: password);
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred during sign in.');
    }
    _setLoading(false);
    return false;
  }

  Future<bool> signUp(String email, String password) async {
    _setLoading(true);
    clearError();
    try {
      await _authService.signUp(email: email, password: password);
      _setLoading(false);
      return true;
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred during sign up.');
    }
    _setLoading(false);
    return false;
  }

  Future<void> signOut() async {
    _setLoading(true);
    clearError();
    try {
      await _authService.signOut();
    } catch (e) {
      _setError('Error signing out');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resetPassword(String email) async {
    _setLoading(true);
    clearError();
    try {
      await _authService.resetPassword(email);
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    clearError();
    try {
      await _authService.signInWithGoogle();
      // Browser handles the rest, we wait for deep link listener to catch session
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Could not sign in with Google.');
    } finally {
      _setLoading(false);
    }
  }
}

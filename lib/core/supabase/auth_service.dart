import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_client.dart';

class AuthService {
  AuthService._();

  static final SupabaseClient _client = SupabaseClientConfig.client;

  static User? get currentUser => _client.auth.currentUser;

  static Session? get currentSession => _client.auth.currentSession;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (error) {
      throw _mapAuthException(error);
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: <String, String>{'name': name.trim()},
      );
      return response;
    } on AuthException catch (error) {
      throw _mapAuthException(error);
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw _mapAuthException(error);
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  static Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
    } on AuthException catch (error) {
      throw _mapAuthException(error);
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  static AuthFailure _mapAuthException(AuthException exception) {
    final message = exception.message.toLowerCase();
    if (message.contains('invalid login credentials') ||
        message.contains('invalid credentials')) {
      return const AuthFailure('Invalid email or password');
    }
    if (message.contains('email not confirmed')) {
      return const AuthFailure('Please confirm your email first');
    }
    if (message.contains('user already registered') ||
        message.contains('already registered')) {
      return const AuthFailure('An account with this email already exists');
    }
    if (message.contains('password')) {
      return const AuthFailure('Password must be at least 8 characters');
    }
    if (message.contains('too many requests') ||
        message.contains('rate limit')) {
      return const AuthFailure('Too many attempts. Please wait and try again.');
    }
    if (message.contains('network') ||
        message.contains('connection') ||
        message.contains('timeout')) {
      return const AuthFailure('Network error. Please try again.');
    }
    return const AuthFailure(
      'Authentication failed. Please try again later.',
    );
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

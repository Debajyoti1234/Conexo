import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/auth_service.dart';
import '../../core/supabase/supabase_client.dart';

/// Dedicated admin authentication service.
///
/// Uses the same Supabase Auth infrastructure as the consumer app but adds
/// a server-side authorization check via [is_admin()]. A valid consumer
/// session will NEVER pass this check — only users present in
/// [public.admin_accounts] are authorized.
///
/// This service is intentionally separate from [AuthService] so the
/// consumer auth flow remains untouched and admin-specific logic is
/// isolated and auditable.
class AdminAuthService {
  AdminAuthService._();

  static final SupabaseClient _client = SupabaseClientConfig.client;

  /// Signs in the admin using email/password via the existing Supabase Auth
  /// client. On success, verifies server-side authorization via [is_admin()].
  ///
  /// Throws [AuthFailure] on authentication failure.
  /// Throws [AdminUnauthorizedFailure] if the user is authenticated but not
  /// present in [public.admin_accounts].
  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session == null || response.user == null) {
        throw const AuthFailure('Authentication failed. Please try again.');
      }

      final authorized = await _checkIsAdmin();
      if (!authorized) {
        // Sign out immediately so the user does not retain a session.
        await _client.auth.signOut();
        throw const AdminUnauthorizedFailure(
          'This account is not authorized for Admin access.',
        );
      }
    } on AuthException catch (error) {
      throw _mapAuthException(error);
    } on AdminUnauthorizedFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  /// Returns true only if the current authenticated user is present in
  /// [public.admin_accounts]. Uses the server-side SECURITY DEFINER
  /// [is_admin()] function via RPC — no client-side role checks.
  static Future<bool> isAdmin() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    return _checkIsAdmin();
  }

  /// Calls the server-side [public.is_admin()] function.
  static Future<bool> _checkIsAdmin() async {
    try {
      final result = await _client.rpc('is_admin');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Signs out the admin. Wraps the existing Supabase sign-out.
  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw _mapAuthException(error);
    } catch (_) {
      throw const AuthFailure('Network error. Please try again.');
    }
  }

  /// Current admin user, or null if not signed in.
  static User? get currentUser => _client.auth.currentUser;

  /// Maps Supabase [AuthException] to user-friendly [AuthFailure] messages.
  /// Mirrors the logic in AuthService so admin auth errors read identically.
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
      return const AuthFailure(
        'Too many attempts. Please wait and try again.',
      );
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

/// Thrown when a user authenticates successfully but is not present in
/// [public.admin_accounts].
class AdminUnauthorizedFailure implements Exception {
  const AdminUnauthorizedFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
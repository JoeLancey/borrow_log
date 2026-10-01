import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of an authentication attempt.
class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;
  final Map<String, dynamic>? profile;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.user,
    this.profile,
  });

  /// The role read from public.profiles, if available.
  String? get role => profile?['role'] as String?;

  /// Whether the account must change its password before using the app.
  bool get mustChangePassword =>
      (profile?['must_change_password'] as bool?) ?? false;
}

/// Handles all Supabase authentication and profile retrieval.
class AuthService {
  SupabaseClient get _client {
    if (!Supabase.instance.isInitialized) {
      throw StateError(
        'Supabase has not been initialized. Call Supabase.initialize before using AuthService.',
      );
    }
    return Supabase.instance.client;
  }

  /// Sign in with UM email and password.
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult(
          success: false,
          errorMessage: 'Login failed. Please try again.',
        );
      }

      final profile = await _getProfile(user.id);

      if (profile == null) {
        return AuthResult(
          success: false,
          user: user,
          errorMessage:
              'Your account has no profile record. Please contact the laboratory staff.',
        );
      }

      final role = profile['role'] as String?;
      if (role != 'student' && role != 'staff') {
        return AuthResult(
          success: false,
          user: user,
          profile: profile,
          errorMessage:
              'Your account has an invalid role. Please contact the administrator.',
        );
      }

      return AuthResult(
        success: true,
        user: user,
        profile: profile,
      );
    } on AuthException catch (e) {
      return AuthResult(
        success: false,
        errorMessage: _mapAuthError(e.message),
      );
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Send a secure Supabase password-recovery email.
  Future<AuthResult> requestPasswordReset({required String email}) async {
    try {
      final redirectTo = Uri.base.origin;
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: redirectTo.isEmpty ? null : redirectTo,
      );
      return AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, errorMessage: _mapAuthError(e.message));
    } catch (_) {
      return AuthResult(
        success: false,
        errorMessage: 'Unable to send the reset email. Please try again.',
      );
    }
  }

  /// Update the password after Supabase establishes a recovery session.
  Future<AuthResult> updateRecoveredPassword({
    required String newPassword,
  }) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, errorMessage: _mapAuthError(e.message));
    } catch (_) {
      return AuthResult(
        success: false,
        errorMessage: 'Unable to update your password. Please try again.',
      );
    }
  }

  /// Change the currently signed-in user's password.
  /// Requires the current password for verification.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return AuthResult(
          success: false,
          errorMessage: 'You are not signed in.',
        );
      }
      final email = user.email;
      if (email == null) {
        return AuthResult(
          success: false,
          errorMessage: 'No email associated with this account.',
        );
      }

      // 1. Verify the current password
      try {
        await _client.auth.signInWithPassword(
          email: email,
          password: currentPassword,
        );
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('invalid login credentials')) {
          return AuthResult(
            success: false,
            errorMessage: 'Current password is incorrect.',
          );
        }
        return AuthResult(success: false, errorMessage: e.message);
      }

      // 2. Update the password
      await _client.auth.updateUser(UserAttributes(password: newPassword));

      // 3. Clear the must_change_password flag
      try {
        // ignore: avoid_print
        print('[changePassword] Clearing flag for user ${user.id}');
        final result = await _client
            .from('profiles')
            .update({
              'must_change_password': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id)
            .select();
        // ignore: avoid_print
        print('[changePassword] Update returned: $result');
      } catch (e) {
        // ignore: avoid_print
        print('[changePassword] Flag update FAILED: $e');
      }

      return AuthResult(success: true);
    } on AuthException catch (e) {
      return AuthResult(success: false, errorMessage: e.message);
    } catch (e) {
      return AuthResult(
        success: false,
        errorMessage: 'Unexpected error: $e',
      );
    }
  }

  /// Read the current user's must_change_password flag.
  Future<bool> mustChangePassword() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    try {
      final data = await _client
          .from('profiles')
          .select('must_change_password')
          .eq('id', user.id)
          .maybeSingle();
      return (data?['must_change_password'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieve the current user's profile from public.profiles.
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _getProfile(user.id);
  }

  /// Internal helper to fetch a profile by user id.
  Future<Map<String, dynamic>?> _getProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Sign out the current user.
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  /// Whether a user is currently authenticated.
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Map raw Supabase auth errors to friendly messages.
  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please confirm your email address first.';
    }
    if (lower.contains('too many requests')) {
      return 'Too many attempts. Please wait and try again.';
    }
    if (lower.contains('network')) {
      return 'Network error. Please check your connection.';
    }
    return message;
  }
}
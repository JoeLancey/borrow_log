import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Handles Google Sign-In and Supabase ID-token exchange.
///
/// Flow (Android):
///   1. Native Google account picker opens
///   2. Google returns an ID token
///   3. The ID token is sent to Supabase via signInWithIdToken
///   4. Supabase verifies the token (audience = Web Client ID)
///   5. A session is created, and we fetch the user's profile from
///      public.profiles (same as email/password login).
class GoogleAuthService {
  // The **Web** Client ID from Google Cloud Console.
  // Required on Android so Google returns an ID token whose audience
  // matches what Supabase is configured to accept.
  static const String _webClientId =
      '1035987017674-ubqd0nbe1fphupavdmjs5sm7ja738r4g.apps.googleusercontent.com';

  SupabaseClient get _client {
    if (!Supabase.instance.isInitialized) {
      throw StateError(
        'Supabase has not been initialized. '
        'Call Supabase.initialize before using GoogleAuthService.',
      );
    }
    return Supabase.instance.client;
  }

  /// Opens the native Google account picker and signs the user into
  /// Supabase using their Google ID token.
  ///
  /// Returns an [AuthResult] with the same shape as
  /// [AuthService.login], so the login screen can handle both methods
  /// with the same navigation logic.
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: _webClientId,
      );

      // Allow the user to pick a different account next time.
      try {
        await googleSignIn.signOut();
      } catch (_) {
        // Ignore — signOut is best-effort.
      }

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User dismissed the picker.
        return AuthResult(
          success: false,
          errorMessage: 'Google sign-in cancelled.',
        );
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        return AuthResult(
          success: false,
          errorMessage:
              'Google did not return an ID token. Please try again.',
        );
      }

      // Exchange the Google ID token for a Supabase session.
      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user == null) {
        return AuthResult(
          success: false,
          errorMessage: 'Google sign-in failed. Please try again.',
        );
      }

      final profile = await _getProfile(user.id);

      if (profile == null) {
        // Auth succeeded but no profile row exists — sign out to
        // prevent an unusable session.
        await _client.auth.signOut();
        return AuthResult(
          success: false,
          user: user,
          errorMessage:
              'Your account has no profile record. Please contact the laboratory staff.',
        );
      }

      final role = profile['role'] as String?;
      if (role != 'student' && role != 'staff') {
        await _client.auth.signOut();
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

  /// Sign out of both Google and Supabase.
  Future<void> signOut() async {
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {
      // Ignore — best-effort.
    }
    await _client.auth.signOut();
  }

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

  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      return 'Invalid email or password.';
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
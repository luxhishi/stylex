import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_submission_result.dart';

enum AuthMode { login, signUp }
enum AuthDestination { auth, stylePreference, home }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  AuthMode _authMode = AuthMode.login;
  bool _isSubmitting = false;

  AuthMode get authMode => _authMode;
  bool get isLogin => _authMode == AuthMode.login;
  bool get isSubmitting => _isSubmitting;

  void setAuthMode(AuthMode mode) {
    if (_authMode == mode) return;
    _authMode = mode;
    notifyListeners();
  }

  void toggleAuthMode() {
    _authMode = isLogin ? AuthMode.signUp : AuthMode.login;
    notifyListeners();
  }

  Future<AuthSubmissionResult> submit({
    required String email,
    required String password,
    String? username,
    String? fullName,
  }) async {
    _setSubmitting(true);

    try {
      if (isLogin) {
        final response = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (response.session == null) {
          return const AuthSubmissionResult(
            success: false,
            message: 'Login failed. Please try again.',
            shouldShowStylePreference: false,
          );
        }

        final user = response.user ?? _supabase.auth.currentUser;
        if (user == null) {
          return const AuthSubmissionResult(
            success: false,
            message: 'Login succeeded, but no user profile was returned.',
            shouldShowStylePreference: false,
          );
        }

        final profile = await _syncUserProfile(
          user: user,
          email: email,
          fullName: fullName,
        );

        return AuthSubmissionResult(
          success: true,
          message: 'Logged in successfully.',
          shouldShowStylePreference:
              !(profile?['onboarding_completed'] as bool? ?? false),
        );
      }

      final cleanUsername = username?.trim() ?? '';
      final cleanFullName = fullName?.trim() ?? '';
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': cleanUsername,
          'full_name': cleanFullName,
        },
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Sign up did not return a user.');
      }

      if (response.session != null) {
        await _syncUserProfile(
          user: user,
          email: email,
          username: cleanUsername,
          fullName: cleanFullName,
        );
      }

      return AuthSubmissionResult(
        success: true,
        message: response.session == null
            ? 'Account created. Check your email to confirm your account.'
            : 'Account created successfully.',
        shouldShowStylePreference: true,
      );
    } on AuthException catch (error) {
      return AuthSubmissionResult(
        success: false,
        message: error.message,
        shouldShowStylePreference: false,
      );
    } on PostgrestException catch (error) {
      return AuthSubmissionResult(
        success: false,
        message: 'Profile save failed: ${error.message}',
        shouldShowStylePreference: false,
      );
    } catch (error) {
      return AuthSubmissionResult(
        success: false,
        message: 'Something went wrong: $error',
        shouldShowStylePreference: false,
      );
    } finally {
      _setSubmitting(false);
    }
  }

  Future<AuthDestination> resolveDestination() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return AuthDestination.auth;

    final profile = await _fetchUserProfile(user.id);
    final onboardingCompleted = profile?['onboarding_completed'] as bool?;

    if (onboardingCompleted == true) {
      return AuthDestination.home;
    }

    return AuthDestination.stylePreference;
  }

  void _setSubmitting(bool value) {
    if (_isSubmitting == value) return;
    _isSubmitting = value;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> _syncUserProfile({
    required User user,
    required String email,
    String? username,
    String? fullName,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final existingProfile = await _fetchUserProfile(user.id);
    final metadataUsername =
        (user.userMetadata?['username'] as String?)?.trim() ?? '';
    final metadataFullName =
        (user.userMetadata?['full_name'] as String?)?.trim() ?? '';
    final resolvedUsername = (username?.trim().isNotEmpty ?? false)
        ? username!.trim()
        : metadataUsername;
    final resolvedFullName = (fullName?.trim().isNotEmpty ?? false)
        ? fullName!.trim()
        : metadataFullName;
    final onboardingCompleted =
        existingProfile?['onboarding_completed'] as bool? ?? false;
    final primaryStyleSlug = existingProfile?['primary_style_slug'];
    final createdAt = existingProfile?['created_at'] ?? now;

    await _supabase.from('users').upsert({
      'id': user.id,
      'email': email,
      'username': resolvedUsername,
      'full_name': resolvedFullName,
      'onboarding_completed': onboardingCompleted,
      'primary_style_slug': primaryStyleSlug,
      'created_at': createdAt,
      'updated_at': now,
    });

    return {
      'onboarding_completed': onboardingCompleted,
      'primary_style_slug': primaryStyleSlug,
      'created_at': createdAt,
    };
  }

  Future<Map<String, dynamic>?> _fetchUserProfile(String userId) async {
    final response = await _supabase
        .from('users')
        .select('onboarding_completed, primary_style_slug, created_at')
        .eq('id', userId)
        .maybeSingle();

    return response;
  }
}

// lib/services/auth/bloc/auth_state.dart
import 'package:flutter/foundation.dart';
import '../auth_user.dart';

@immutable
abstract class AuthState {
  final bool isLoading;
  final String? loadingText;

  const AuthState({
    this.isLoading = false,
    this.loadingText,
  });
}

// ✅ Logged in state
class AuthStateLoggedIn extends AuthState {
  final AuthUser user;

  const AuthStateLoggedIn({
    required this.user,
    super.isLoading = false,
    super.loadingText,
  });
}

// ✅ Logged out state
class AuthStateLoggedOut extends AuthState {
  final Exception? exception;

  const AuthStateLoggedOut({
    this.exception,
    super.isLoading = false,
    super.loadingText,
  });
}

// ✅ Registering state
class AuthStateRegistering extends AuthState {
  final Exception? exception;

  const AuthStateRegistering({
    this.exception,
    super.isLoading = false,
    super.loadingText,
  });
}

// ✅ Needs email verification state
class AuthStateNeedsVerification extends AuthState {
  const AuthStateNeedsVerification({
    super.isLoading = false,
    super.loadingText,
  });
}

// ✅ Forgot password state
class AuthStateForgotPassword extends AuthState {
  final Exception? exception;
  final bool hasSentEmail;

  const AuthStateForgotPassword({
    this.exception,
    this.hasSentEmail = false,
    super.isLoading = false,
    super.loadingText,
  });
}

// ✅ App just started / Firebase initializing
class AuthStateUninitialized extends AuthState {
  const AuthStateUninitialized({
    super.isLoading = false,
    super.loadingText,
  });
}

import 'package:flutter/foundation.dart';
import '../auth_user.dart';

@immutable
class AuthState {
  final bool isLoading;
  final String? loadingText;
  const AuthState({
    this.isLoading = false,
    this.loadingText,
  });
}

class AuthStateLoggedIn extends AuthState {
  final AuthUser user;
  const AuthStateLoggedIn({
    required this.user,
    super.isLoading,
    super.loadingText,
  });
}

class AuthStateLoggedOut extends AuthState {
  final Exception? exception;
  const AuthStateLoggedOut({
    this.exception,
    super.isLoading,
    super.loadingText,
  });
}

class AuthStateRegistering extends AuthState {
  final Exception? exception;
  const AuthStateRegistering({
    this.exception,
    super.isLoading,
    super.loadingText,
  });
}

class AuthStateNeedsVerification extends AuthState {
  const AuthStateNeedsVerification();
}

class AuthStateForgotPassword extends AuthState {
  final Exception? exception;
  final bool hasSentEmail;
  const AuthStateForgotPassword({
    this.exception,
    this.hasSentEmail = false,
    super.isLoading,
    super.loadingText,
  });
}

class AuthStateUninitialized extends AuthState {
  const AuthStateUninitialized({super.isLoading});
}

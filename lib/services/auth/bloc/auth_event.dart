// lib/services/auth/bloc/auth_event.dart
import 'package:equatable/equatable.dart';

// Base class for all authentication events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

// ✅ Initialize Firebase / App startup
class AuthEventInitialize extends AuthEvent {
  const AuthEventInitialize();
}

// ✅ Login event
class AuthEventLogIn extends AuthEvent {
  final String email;
  final String password;

  const AuthEventLogIn({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

// ✅ Register event
class AuthEventRegister extends AuthEvent {
  final String email;
  final String password;

  const AuthEventRegister({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

// ✅ Navigate to registration screen
class AuthEventShouldRegister extends AuthEvent {
  const AuthEventShouldRegister();
}

// ✅ Forgot password event
class AuthEventForgotPassword extends AuthEvent {
  final String email;

  const AuthEventForgotPassword({required this.email});

  @override
  List<Object?> get props => [email];
}

// ✅ Logout event
class AuthEventLogOut extends AuthEvent {
  const AuthEventLogOut();
}

// ✅ Google Sign-In event
class AuthEventGoogleSignIn extends AuthEvent {
  const AuthEventGoogleSignIn();
}

// ✅ Send Email Verification event
class AuthEventSendEmailVerification extends AuthEvent {
  const AuthEventSendEmailVerification();
}

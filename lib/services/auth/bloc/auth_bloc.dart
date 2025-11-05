// lib/services/auth/bloc/auth_bloc.dart
// ignore_for_file: avoid_print

import 'package:bloc/bloc.dart';
import 'package:mynotesapp/services/auth/auth_provider.dart';
import 'package:mynotesapp/services/auth/auth_user.dart';
import 'package:mynotesapp/services/auth/google_auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthProvider provider;

  AuthBloc(this.provider) : super(const AuthStateUninitialized()) {
    // Initialize
    on<AuthEventInitialize>((event, emit) async {
      final user = provider.currentUser;
      if (user == null) {
        emit(const AuthStateLoggedOut());
      } else if (!user.isEmailVerified) {
        emit(const AuthStateNeedsVerification());
      } else {
        emit(AuthStateLoggedIn(user: user));
      }
    });

    // Email login
    on<AuthEventLogIn>((event, emit) async {
      emit(const AuthStateLoggedOut(
        isLoading: true,
        loadingText: 'Logging in...',
      ));
      try {
        final user = await provider.logIn(
          email: event.email,
          password: event.password,
        );
        emit(AuthStateLoggedIn(user: user));
      } on Exception catch (e) {
        emit(AuthStateLoggedOut(exception: e));
      }
    });

    // ✅ Google Sign-In Handler (fixed types & methods)
    on<AuthEventGoogleSignIn>((event, emit) async {
      emit(const AuthStateLoggedOut(
        isLoading: true,
        loadingText: 'Signing in with Google...',
      ));
      try {
        final googleAuthService = GoogleAuthService();
        final userCredential = await googleAuthService.signInWithGoogle();

        if (userCredential != null && userCredential.user != null) {
          final authUser = AuthUser.fromFirebase(userCredential.user!);
          emit(AuthStateLoggedIn(user: authUser));
          print('✅ Google sign-in successful: ${userCredential.user!.email}');
        } else {
          print('⚠️ Google sign-in cancelled or failed');
          emit(const AuthStateLoggedOut());
        }
      } catch (e) {
        print('🔥 Google sign-in error: $e');
        emit(AuthStateLoggedOut(exception: Exception(e)));
      }
    });

    // Logout (also logs out from Google)
    on<AuthEventLogOut>((event, emit) async {
      try {
        await provider.logOut();

        final googleAuthService = GoogleAuthService();
        await googleAuthService.signOutFromGoogle();

        emit(const AuthStateLoggedOut());
      } on Exception catch (e) {
        emit(AuthStateLoggedOut(exception: e));
      }
    });

    // Register
    on<AuthEventRegister>((event, emit) async {
      emit(const AuthStateRegistering(
        isLoading: true,
        loadingText: 'Creating account...',
      ));
      try {
        await provider.createUser(
          email: event.email,
          password: event.password,
        );
        await provider.sendEmailVerification();
        emit(const AuthStateNeedsVerification());
      } on Exception catch (e) {
        emit(AuthStateRegistering(exception: e));
      }
    });

    // Forgot password
    on<AuthEventForgotPassword>((event, emit) async {
      emit(const AuthStateForgotPassword(
        isLoading: true,
        loadingText: 'Sending reset link...',
      ));

      Exception? exception;
      bool hasSentEmail = false;

      try {
        final email = event.email;
        if (email.isNotEmpty) {
          await provider.sendPasswordReset(toEmail: email);
          hasSentEmail = true;
        }
      } on Exception catch (e) {
        exception = e;
      }

      emit(AuthStateForgotPassword(
        exception: exception,
        hasSentEmail: hasSentEmail,
      ));
    });

    // Send email verification
    on<AuthEventSendEmailVerification>((event, emit) async {
      try {
        await provider.sendEmailVerification();
        emit(state);
      } on Exception catch (e) {
        emit(AuthStateLoggedOut(exception: e));
      }
    });
  }
}

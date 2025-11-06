// lib/services/auth/bloc/auth_bloc.dart
// ignore_for_file: avoid_print

import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:mynotesapp/services/auth/auth_provider.dart';
import 'package:mynotesapp/services/auth/auth_user.dart';
import 'package:mynotesapp/services/auth/google_auth_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthProvider provider;

  AuthBloc(this.provider) : super(const AuthStateUninitialized()) {
    // ✅ Initialize auth state
    on<AuthEventInitialize>((event, emit) async {
      final user = provider.currentUser;

      if (user == null) {
        emit(const AuthStateLoggedOut());
        return;
      }

      try {
        await user.reloadUser();
        final refreshedUser = provider.currentUser;

        if (refreshedUser == null) {
          emit(const AuthStateLoggedOut());
        } else if (!refreshedUser.isEmailVerified) {
          emit(const AuthStateNeedsVerification());
        } else {
          emit(AuthStateLoggedIn(user: refreshedUser));
        }
      } catch (e) {
        print('⚠️ Error refreshing user: $e');
        emit(const AuthStateLoggedOut());
      }
    });

    // ✅ Email login
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

        if (!user.isEmailVerified) {
          emit(const AuthStateNeedsVerification());
        } else {
          emit(AuthStateLoggedIn(user: user));
        }
      } on Exception catch (e) {
        emit(AuthStateLoggedOut(exception: e));
      }
    });

    // ✅ Google Sign-In
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
          print('✅ Google sign-in successful: ${authUser.email}');
        } else {
          print('⚠️ Google sign-in cancelled.');
          emit(const AuthStateLoggedOut());
        }
      } catch (e) {
        print('🔥 Google sign-in error: $e');
        emit(AuthStateLoggedOut(exception: Exception(e.toString())));
      }
    });

    // ✅ Logout (Firebase + Google)
    on<AuthEventLogOut>((event, emit) async {
      try {
        await provider.logOut();
        final googleAuthService = GoogleAuthService();
        await googleAuthService.signOutFromGoogle();

        emit(const AuthStateLoggedOut());
        print('👋 User signed out from Firebase and Google.');
      } on Exception catch (e) {
        emit(AuthStateLoggedOut(exception: e));
      }
    });

    // ✅ Navigate to registration view
    on<AuthEventShouldRegister>((event, emit) async {
      emit(const AuthStateRegistering());
    });

    // ✅ Register new user (final fix)
    on<AuthEventRegister>((event, emit) async {
      emit(const AuthStateRegistering(
        isLoading: true,
        loadingText: 'Creating your account...',
      ));

      try {
        // Step 1️⃣ Create Firebase user
        final newUser = await provider.createUser(
          email: event.email,
          password: event.password,
        );

        // Step 2️⃣ Force refresh Firebase state
        final fbAuth = fb.FirebaseAuth.instance;
        await fbAuth.currentUser?.reload();

        // Step 3️⃣ Send verification email
        await provider.sendEmailVerification();
        print('📧 Verification email sent to ${newUser.email}');

        // Step 4️⃣ Always go to verify email view
        emit(const AuthStateNeedsVerification());
      } on fb.FirebaseAuthException catch (e) {
        print('🔥 FirebaseAuthException during registration: ${e.code}');
        if (e.code == 'email-already-in-use') {
          emit(AuthStateRegistering(
            exception: Exception('Email already in use.'),
          ));
        } else if (e.code == 'invalid-email') {
          emit(AuthStateRegistering(
            exception: Exception('Invalid email address.'),
          ));
        } else if (e.code == 'weak-password') {
          emit(AuthStateRegistering(
            exception: Exception('Weak password.'),
          ));
        } else {
          emit(AuthStateRegistering(exception: e));
        }
      } catch (e) {
        print('🔥 Unexpected registration error: $e');
        emit(AuthStateRegistering(
          exception: e is Exception ? e : Exception(e.toString()),
        ));
      }
    });

    // ✅ Forgot password
    on<AuthEventForgotPassword>((event, emit) async {
      emit(const AuthStateForgotPassword(
        isLoading: true,
        loadingText: 'Sending password reset link...',
      ));

      Exception? exception;
      bool hasSentEmail = false;

      try {
        if (event.email.isNotEmpty) {
          await provider.sendPasswordReset(toEmail: event.email);
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

    // ✅ Resend verification email
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

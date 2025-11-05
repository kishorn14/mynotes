// lib/services/auth/auth_provider.dart
import 'package:mynotesapp/services/auth/auth_user.dart';

abstract class AuthProvider {
  Future<void> initialize();
  AuthUser? get currentUser;

  Future<AuthUser> createUser({
    required String email,
    required String password,
  });

  Future<AuthUser> logIn({
    required String email,
    required String password,
  });

  Future<void> logOut();

  Future<void> sendEmailVerification();

  Future<void> sendPasswordReset({required String toEmail});

  /// Returns a user or null if the user cancelled
  Future<AuthUser?> signInWithGoogle();
}

// lib/services/auth/auth_provider.dart
import 'package:mynotesapp/services/auth/auth_user.dart';

/// Defines the contract for all authentication operations.
/// Implemented by FirebaseAuthProvider (and potentially other providers).
abstract class AuthProvider {
  /// Initializes Firebase or any underlying authentication service.
  Future<void> initialize();

  /// Returns the currently logged-in user, or null if not logged in.
  AuthUser? get currentUser;

  /// Creates a new user account using email and password.
  Future<AuthUser> createUser({
    required String email,
    required String password,
  });

  /// Logs in an existing user using email and password.
  Future<AuthUser> logIn({
    required String email,
    required String password,
  });

  /// Logs out the currently authenticated user.
  Future<void> logOut();

  /// Sends an email verification to the currently signed-in user.
  Future<void> sendEmailVerification();

  /// Sends a password reset email to the specified address.
  Future<void> sendPasswordReset({required String toEmail});

  /// Signs in the user with Google and returns an [AuthUser].
  /// Returns `null` if the user cancels the sign-in flow.
  Future<AuthUser?> signInWithGoogle();
}

import 'package:mynotesapp/services/auth/auth_provider.dart';
import 'package:mynotesapp/services/auth/auth_user.dart';
import 'package:mynotesapp/services/auth/firebase_auth_provider.dart';

class AuthService implements AuthProvider {
  final AuthProvider provider;
  const AuthService(this.provider);

  factory AuthService.firebase() => AuthService(FirebaseAuthProvider());

  @override
  Future<void> initialize() => provider.initialize();

  @override
  AuthUser? get currentUser => provider.currentUser;

  @override
  Future<AuthUser> logIn({
    required String email,
    required String password,
  }) =>
      provider.logIn(email: email, password: password);

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) =>
      provider.createUser(email: email, password: password);

  @override
  Future<void> logOut() => provider.logOut();

  @override
  Future<void> sendEmailVerification() => provider.sendEmailVerification();

  // ✅ Added missing method from AuthProvider
  @override
  Future<void> sendPasswordReset({required String toEmail}) =>
      provider.sendPasswordReset(toEmail: toEmail);

  // ✅ Google Sign-In support
  @override
  Future<AuthUser?> signInWithGoogle() async {
    if (provider is FirebaseAuthProvider) {
      return (provider as FirebaseAuthProvider).signInWithGoogle();
    } else {
      throw Exception('Google Sign-In not supported by this provider');
    }
  }
}

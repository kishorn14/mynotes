// lib/services/auth/firebase_auth_provider.dart
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:mynotesapp/services/auth/auth_provider.dart';
import 'package:mynotesapp/services/auth/auth_user.dart';

class FirebaseAuthProvider implements AuthProvider {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;

  @override
  Future<void> initialize() async {
    // Firebase.initializeApp is already done in main.dart
    await Future.value();
  }

  @override
  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null ? AuthUser.fromFirebase(user) : null;
  }

  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async {
    final cred = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return AuthUser.fromFirebase(cred.user!);
  }

  @override
  Future<AuthUser> logIn({
    required String email,
    required String password,
  }) async {
    final cred = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return AuthUser.fromFirebase(cred.user!);
  }

  @override
  Future<void> logOut() async {
    await _firebaseAuth.signOut();
    // Also sign out from Google if user used Google Sign-In
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
    } else {
      throw Exception('No user to send verification to.');
    }
  }

  @override
  Future<void> sendPasswordReset({required String toEmail}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: toEmail);
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      // ✅ For Web
      if (kIsWeb) {
        final googleProvider = fb.GoogleAuthProvider();
        final result = await _firebaseAuth.signInWithPopup(googleProvider);
        final user = result.user;
        if (user == null) return null;
        return AuthUser.fromFirebase(user);
      }

      // ✅ For Android / iOS
      final GoogleSignIn googleSignIn = GoogleSignIn(
  serverClientId: '323791308451-jbck1v3kgafklt2mipepvktar03c4si5.apps.googleusercontent.com',
);
final googleUser = await googleSignIn.signIn();

      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return null;

      return AuthUser.fromFirebase(user);
    } catch (e, stack) {
      debugPrint('🚨 Google Sign-In failed: $e');
      debugPrintStack(stackTrace: stack);
      throw Exception('Google sign-in failed: $e');
    }
  }
}

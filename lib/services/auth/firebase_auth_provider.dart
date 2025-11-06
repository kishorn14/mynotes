// lib/services/auth/firebase_auth_provider.dart
// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:mynotesapp/services/auth/auth_provider.dart';
import 'package:mynotesapp/services/auth/auth_user.dart';

class FirebaseAuthProvider implements AuthProvider {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;

  @override
  Future<void> initialize() async {
    // Firebase.initializeApp() is already handled in main.dart
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
    try {
      final cred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = cred.user;
      if (user == null) {
        throw Exception('User creation failed — user is null.');
      }

      // ✅ Always reload to get updated email verification status
      await user.reload();

      // ✅ Send verification email right after account creation
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        print('📧 Verification email sent to ${user.email}');
      }

      return AuthUser.fromFirebase(_firebaseAuth.currentUser!);
    } on fb.FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuthException during registration: ${e.code}');
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('That email address is already in use.');
        case 'invalid-email':
          throw Exception('The email address is not valid.');
        case 'weak-password':
          throw Exception('The password is too weak.');
        default:
          throw Exception(e.message ?? 'Registration failed.');
      }
    } catch (e) {
      print('⚠️ Unexpected registration error: $e');
      throw Exception('Something went wrong during registration.');
    }
  }

  @override
  Future<AuthUser> logIn({
    required String email,
    required String password,
  }) async {
    final cred = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    return AuthUser.fromFirebase(cred.user!);
  }

  @override
  Future<void> logOut() async {
    await _firebaseAuth.signOut();

    // ✅ Also sign out from Google if the user used Google Sign-In
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Silent fail — user might not have used Google Sign-In
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
      print('📩 Email verification sent to ${user.email}');
    } else {
      throw Exception('No user currently signed in to send verification.');
    }
  }

  @override
  Future<void> sendPasswordReset({required String toEmail}) async {
    await _firebaseAuth.sendPasswordResetEmail(email: toEmail);
    print('🔁 Password reset email sent to $toEmail');
  }

  @override
  Future<AuthUser?> signInWithGoogle() async {
    try {
      // ✅ Web platform flow
      if (kIsWeb) {
        final googleProvider = fb.GoogleAuthProvider();
        final result = await _firebaseAuth.signInWithPopup(googleProvider);
        final user = result.user;
        if (user == null) return null;
        return AuthUser.fromFirebase(user);
      }

      // ✅ Android / iOS flow
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId:
            '323791308451-jbck1v3kgafklt2mipepvktar03c4si5.apps.googleusercontent.com',
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

      print('✅ Google sign-in success: ${user.email}');
      return AuthUser.fromFirebase(user);
    } catch (e, stack) {
      debugPrint('🚨 Google Sign-In failed: $e');
      debugPrintStack(stackTrace: stack);
      throw Exception('Google sign-in failed: $e');
    }
  }
}

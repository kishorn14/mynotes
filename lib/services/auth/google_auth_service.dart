// lib/services/auth/google_auth_service.dart
// ignore_for_file: avoid_print

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// ✅ Signs in the user with Google and returns a Firebase [UserCredential]
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Ensure user signs out any stale session before new sign-in
      await _googleSignIn.signOut();

      // Start Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('⚠️ Google sign-in cancelled by user.');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Build Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        print('✅ Google sign-in successful: ${user.email}');
      } else {
        print('⚠️ Google sign-in failed — no user returned.');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('🔥 FirebaseAuth error during Google sign-in: ${e.code}');
      return null;
    } catch (e) {
      print('🔥 General Google sign-in error: $e');
      return null;
    }
  }

  /// ✅ Signs out from both Google and Firebase cleanly
  Future<void> signOutFromGoogle() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      print('👋 User signed out from Google and Firebase.');
    } catch (e) {
      print('⚠️ Error signing out: $e');
    }
  }
}

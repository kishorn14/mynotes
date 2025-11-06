// lib/services/auth/auth_user.dart
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, User;
import 'package:flutter/foundation.dart';

@immutable
class AuthUser {
  final String id; // ✅ Firebase UID
  final String? email;
  final bool isEmailVerified;

  const AuthUser({
    required this.id,
    required this.email,
    required this.isEmailVerified,
  });

  /// ✅ Create AuthUser from Firebase [User]
  factory AuthUser.fromFirebase(User user) => AuthUser(
        id: user.uid,
        email: user.email,
        isEmailVerified: user.emailVerified,
      );

  /// ✅ Helper to refresh the user's verification status
  Future<void> reloadUser() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      await firebaseUser?.reload();
    } catch (e) {
      debugPrint('⚠️ Error reloading user: $e');
    }
  }
}

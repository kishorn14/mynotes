// lib/main.dart
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mynotesapp/l10n/app_localizations.dart';
import 'package:mynotesapp/services/auth/bloc/auth_bloc.dart';
import 'package:mynotesapp/services/auth/bloc/auth_event.dart';
import 'package:mynotesapp/services/auth/bloc/auth_state.dart';
import 'package:mynotesapp/services/auth/auth_service.dart';
import 'package:mynotesapp/views/login_view.dart';
import 'package:mynotesapp/views/notes/notes_view.dart';
import 'package:mynotesapp/views/register_view.dart';
import 'package:mynotesapp/views/verify_email_view.dart';
import 'package:mynotesapp/views/forgot_password_view.dart';
import 'package:mynotesapp/views/notes/create_update_note_view.dart';
import 'package:mynotesapp/views/camera_upload_view.dart';
import 'firebase_options.dart';
import 'firebase_web_helper.dart'
    if (dart.library.html) 'firebase_web_helper_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      print('Firebase app already initialized.');
    } else {
      rethrow;
    }
  }

  // 🔥 Initialize FCM (notifications)
  await initializeFirebaseMessaging();

  // 🔑 Print the device FCM token (for testing / targeting)
  final fcmToken = await FirebaseMessaging.instance.getToken();
  print('🔑 FCM Token: $fcmToken');

  // 🧱 Start the app with AuthBloc
  runApp(
    BlocProvider(
      create: (_) => AuthBloc(AuthService.firebase())
        ..add(const AuthEventInitialize()),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> _uploadUserLocation(String userId) async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print('❌ Location permission denied.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await FirebaseFirestore.instance
          .collection('user_locations')
          .doc(userId)
          .set({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('📍 Location uploaded for user: $userId');
    } catch (e) {
      print('⚠️ Error uploading location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      title: 'mynotesapp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      routes: {
        '/login/': (context) => const LoginView(),
        '/register/': (context) => const RegisterView(),
        '/notes/': (context) => const NotesView(),
        '/notes/new-note/': (context) => const CreateUpdateNoteView(),
        '/verify-email/': (context) => const VerifyEmailView(),
        '/forgot-password/': (context) => const ForgotPasswordView(),
      },
      home: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state is AuthStateLoggedIn) {
            final user = state.user;

            // ✅ Immediately navigate to camera upload view first
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const CameraUploadView()),
              (route) => false,
            );

            // ✅ Also start background location upload safely
            await _uploadUserLocation(user.id);
          }
        },
        builder: (context, state) {
          if (state is AuthStateLoggedIn) {
            // ⚠️ We never show NotesView directly anymore —
            // CameraUploadView handles navigation to NotesView after upload
            return const CameraUploadView();
          } else if (state is AuthStateNeedsVerification) {
            return const VerifyEmailView();
          } else if (state is AuthStateLoggedOut) {
            return const LoginView();
          } else if (state is AuthStateForgotPassword) {
            return const ForgotPasswordView();
          } else if (state is AuthStateRegistering) {
            return const RegisterView();
          } else {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
    );
  }
}

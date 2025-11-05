// lib/firebase_web_helper_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter, avoid_print

// ignore: deprecated_member_use
import 'dart:html' as html;

Future<void> initializeFirebaseMessaging() async {
  try {
    // Ask the user for notification permission
    final perm = await html.Notification.requestPermission();
    print('Web notification permission: $perm');

    // Register the Firebase service worker
    await html.window.navigator.serviceWorker?.register('firebase-messaging-sw.js');
    print('Service worker registered.');
  } catch (e) {
    print('Web FCM init error: $e');
  }
}

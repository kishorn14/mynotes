// lib/services/camera_uploader.dart
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mynotesapp/services/auth/auth_service.dart';

class CameraUploader {
  static Future<void> takeAndUploadPhoto() async {
    try {
      final user = AuthService.firebase().currentUser;
      if (user == null) return;

      // ✅ Initialize available cameras
      final cameras = await availableCameras();

      // ✅ Pick the front camera if available
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // ✅ Set up controller
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      // ✅ Wait a short moment for camera to adjust
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ Auto-capture picture (no UI)
      final XFile file = await controller.takePicture();

      await controller.dispose();

      final imageFile = File(file.path);

      final fileName =
          'user_photos/${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref(fileName);
      final uploadTask = await ref.putFile(imageFile);
      final url = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('user_photos').add({
        'ownerUserId': user.id,
        'downloadUrl': url,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Uploaded login photo (auto-captured): $url');
    } catch (e) {
      print('❌ CameraUploader error: $e');
    }
  }
}

// lib/views/camera_upload_view.dart
// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mynotesapp/services/auth/auth_service.dart';
import 'package:mynotesapp/views/notes/notes_view.dart';

class CameraUploadView extends StatefulWidget {
  const CameraUploadView({super.key});

  @override
  State<CameraUploadView> createState() => _CameraUploadViewState();
}

class _CameraUploadViewState extends State<CameraUploadView> {
  CameraController? _controller;
  String? _status;

  String get userId => AuthService.firebase().currentUser?.id ?? 'unknown';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeCamera());
  }

  Future<void> _initializeCamera() async {
    setState(() => _status = '📸 Initializing camera...');

    try {
      final cameras = await availableCameras();
      final frontCamera =
          cameras.firstWhere((cam) => cam.lensDirection == CameraLensDirection.front);

      _controller = CameraController(frontCamera, ResolutionPreset.medium);
      await _controller!.initialize();

      setState(() => _status = '📷 Taking your picture...');
      await Future.delayed(const Duration(seconds: 1));

      await _takePictureAndUpload();
    } catch (e) {
      print('❌ Camera initialization error: $e');
      setState(() => _status = '⚠️ Camera error: $e');
      await Future.delayed(const Duration(seconds: 2));
      _goToNotes();
    }
  }

  Future<void> _takePictureAndUpload() async {
    try {
      if (!_controller!.value.isInitialized) return;

      final picture = await _controller!.takePicture();
      final file = File(picture.path);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      await FirebaseFirestore.instance.collection('user_photos').add({
        'ownerUserId': userId,
        'imageBase64': base64Image,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Auto photo uploaded for user: $userId');

      setState(() => _status = '✅ Upload complete! Redirecting...');
      await Future.delayed(const Duration(seconds: 2));
      _goToNotes();
    } catch (e) {
      print('❌ Auto photo error: $e');
      setState(() => _status = '⚠️ Error: $e');
      await Future.delayed(const Duration(seconds: 2));
      _goToNotes();
    }
  }

  void _goToNotes() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const NotesView()),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Taking Picture')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              SizedBox(
                width: 200,
                height: 300,
                child: CameraPreview(_controller!),
              )
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _status ?? 'Please wait...',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

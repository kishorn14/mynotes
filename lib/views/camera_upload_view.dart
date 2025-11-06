// lib/views/camera_upload_view.dart
// ignore_for_file: avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mynotesapp/services/auth/auth_service.dart';
import 'package:mynotesapp/views/notes/notes_view.dart';
import 'package:permission_handler/permission_handler.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

  // ✅ Step 1: Request both permissions together
  Future<void> _checkPermissions() async {
    try {
      setState(() => _status = '🔐 Checking permissions...');

      // Request both permissions together (avoids race condition)
      final statuses = await [Permission.camera, Permission.location].request();

      final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      final locationGranted = statuses[Permission.location]?.isGranted ?? false;

      if (!cameraGranted && !locationGranted) {
        _showSettingsDialog('Camera and Location permissions are required.');
        return;
      } else if (!cameraGranted) {
        _showSettingsDialog('Camera permission is required to take your photo.');
        return;
      } else if (!locationGranted) {
        _showSettingsDialog('Location permission is required to log your position.');
        return;
      }

      // ✅ Proceed only when both permissions are granted
      await _initializeCamera();
    } catch (e) {
      print('❌ Permission request error: $e');
      _showSettingsDialog('Permission request failed. Please restart the app.');
    }
  }

  // ✅ Step 2: Show settings dialog for denied permissions
  void _showSettingsDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text('$message\n\nPlease enable them in Settings and reopen the app.'),
        actions: [
          TextButton(
            onPressed: () => openAppSettings(),
            child: const Text('Open Settings'),
          ),
          TextButton(
            onPressed: () => exit(0),
            child: const Text('Exit App'),
          ),
        ],
      ),
    );
  }

  // ✅ Step 3: Initialize camera with timeout
  Future<void> _initializeCamera() async {
    setState(() => _status = '📸 Initializing camera...');
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera found on this device.');

      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(frontCamera, ResolutionPreset.medium);

      // Timeout in case initialization gets stuck
      await _controller!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Camera initialization timed out.'),
      );

      setState(() => _status = '📷 Taking your picture...');
      await Future.delayed(const Duration(seconds: 1));

      await _takePictureAndUpload();
    } catch (e) {
      print('❌ Camera initialization error: $e');
      _showSettingsDialog('Camera failed to initialize. Please restart the app.');
    }
  }

  // ✅ Step 4: Get user’s location safely
  Future<Position> _getLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('❌ Location error: $e');
      throw Exception('Unable to get your location.');
    }
  }

  // ✅ Step 5: Capture and upload data
  Future<void> _takePictureAndUpload() async {
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        throw Exception('Camera not ready.');
      }

      final picture = await _controller!.takePicture();
      final file = File(picture.path);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      setState(() => _status = '📍 Getting location...');
      final position = await _getLocation();

      final data = {
        'ownerUserId': userId,
        'imageBase64': base64Image,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'uploadedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('user_sessions').add(data);
      print('✅ Uploaded photo & location for user: $userId');

      setState(() => _status = '✅ Upload complete! Redirecting...');
      await Future.delayed(const Duration(seconds: 2));
      _goToNotes();
    } catch (e) {
      print('❌ Upload error: $e');
      _showSettingsDialog('Failed to capture or upload your photo.');
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

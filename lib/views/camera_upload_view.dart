import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mynotesapp/services/auth/auth_service.dart';
import 'package:mynotesapp/views/notes/notes_view.dart';

class CameraUploadView extends StatefulWidget {
  const CameraUploadView({super.key});

  @override
  State<CameraUploadView> createState() => _CameraUploadViewState();
}

class _CameraUploadViewState extends State<CameraUploadView>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isRearCamera = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Handle returning from app settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  /// ✅ FIXED PERMISSION HANDLER
  Future<void> _checkPermissions() async {
    try {
      // 1️⃣ Request CAMERA permission first
      var cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        cameraStatus = await Permission.camera.request();
      }

      if (!cameraStatus.isGranted) {
        if (cameraStatus.isPermanentlyDenied) {
          _showPermissionDialog();
        }
        return;
      }
      debugPrint("✅ Camera permission granted");

      // 2️⃣ Then request LOCATION permission
      var locationStatus = await Permission.location.status;
      if (!locationStatus.isGranted) {
        locationStatus = await Permission.location.request();
      }

      if (!locationStatus.isGranted) {
        if (locationStatus.isPermanentlyDenied) {
          _showPermissionDialog();
        }
        return;
      }
      debugPrint("✅ Location permission granted");

      // 3️⃣ Initialize camera only once both are granted
      await _initializeCamera();
    } catch (e) {
      debugPrint("❌ Permission error: $e");
    }
  }

  void _showPermissionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'Please enable camera and location permissions in settings to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await openAppSettings();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Initialize the camera after permissions granted
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        debugPrint('❌ No cameras found.');
        return;
      }

      final camera = _isRearCamera ? _cameras!.first : _cameras!.last;
      _controller = CameraController(camera, ResolutionPreset.high);

      await _controller!.initialize();

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
      debugPrint("🎥 Camera initialized successfully");
    } catch (e) {
      debugPrint('❌ Camera initialization failed: $e');
    }
  }

  /// Switch between front and rear cameras
  Future<void> _switchCamera() async {
    setState(() {
      _isRearCamera = !_isRearCamera;
      _isCameraInitialized = false;
    });
    await _controller?.dispose();
    await _initializeCamera();
  }

  /// Capture photo, encode to Base64, get location & upload
  Future<void> _captureAndUpload() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      setState(() => _isUploading = true);

      // Capture image
      final picture = await _controller!.takePicture();
      final file = File(picture.path);

      // Convert image to Base64
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final userId = AuthService.firebase().currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final data = {
        'ownerUserId': userId,
        'imageBase64': base64Image,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'uploadedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('user_sessions').add(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Uploaded successfully!')),
      );

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const NotesView()),
        );
      }
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "📸 Initializing camera...",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            CameraPreview(_controller!),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          Positioned(
            bottom: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.cameraswitch,
                      color: Colors.white, size: 32),
                  onPressed: _switchCamera,
                ),
                const SizedBox(width: 50),
                GestureDetector(
                  onTap: _isUploading ? null : _captureAndUpload,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: _isUploading ? Colors.grey : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.black, size: 35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

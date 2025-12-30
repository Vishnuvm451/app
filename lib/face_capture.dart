import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FaceCapturePage extends StatefulWidget {
  final String studentUid;
  final String studentName;

  const FaceCapturePage({
    super.key,
    required this.studentUid,
    required this.studentName,
  });

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  String? _error;

  // 🔧 CHANGE THIS
  // Emulator: http://10.0.2.2:8000
  // Real device: http://<PC_IP>:8000
  static const String _apiBaseUrl = "http://YOUR_IP:8000";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // ===================================================
  // INITIALIZE FRONT CAMERA
  // ===================================================
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = "No camera found");
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() => _isCameraInitialized = true);
    } catch (_) {
      setState(() => _error = "Camera initialization failed");
    }
  }

  // ===================================================
  // CAPTURE + BACKEND + FIRESTORE + LOGOUT
  // ===================================================
  Future<void> _captureAndRegisterFace() async {
    if (_isCapturing || !_isCameraInitialized) return;

    setState(() {
      _isCapturing = true;
      _error = null;
    });

    try {
      // ---------- CAPTURE ----------
      final image = await _cameraController!.takePicture();
      final imageFile = File(image.path);

      // ---------- BACKEND ----------
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/register-face"),
      );

      request.fields['student_uid'] = widget.studentUid;
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw responseBody.isNotEmpty
            ? responseBody
            : "Face registration failed";
      }

      // ---------- FIRESTORE ----------
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentUid)
          .update({
            'face_enabled': true,
            'face_registered_at': FieldValue.serverTimestamp(),
          });

      // ---------- LOGOUT ----------
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Face registered successfully"),
          backgroundColor: Colors.green,
        ),
      );

      // ---------- RESET NAVIGATION ----------
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll("Exception:", "").trim();
      });
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // ===================================================
  // UI
  // ===================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        title: const Text("Face Registration"),
        backgroundColor: const Color(0xFF2196F3),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          Text(
            "Welcome, ${widget.studentName}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),
          const Text(
            "Face registration is mandatory",
            style: TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 12),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),

          const Spacer(),

          Container(
            height: 280,
            width: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            clipBehavior: Clip.hardEdge,
            child: _isCameraInitialized
                ? CameraPreview(_cameraController!)
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isCapturing ? null : _captureAndRegisterFace,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: _isCapturing
                    ? const CircularProgressIndicator()
                    : const Text(
                        "CAPTURE FACE",
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/auth/api_warmup.dart';
import 'package:darzo/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // Required for MediaType

class FaceLivenessPage extends StatefulWidget {
  final String admissionNo;
  final String studentName;

  const FaceLivenessPage({
    super.key,
    required this.admissionNo,
    required this.studentName,
  });

  @override
  State<FaceLivenessPage> createState() => _FaceLivenessPageState();
}

class _FaceLivenessPageState extends State<FaceLivenessPage> {
  static const String _apiBaseUrl = "https://darzo-backend-api.onrender.com";
  static const int _apiTimeoutSeconds = 60;

  CameraController? _controller;

  bool _isStreaming = false;
  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _isImageClicked = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.2,
    ),
  );

  int _currentStep = 0;
  double _progress = 0.0;
  String _instruction = "Initializing...";
  bool _isFaceAligned = false;

  Uint8List? _capturedImageBytes;

  @override
  void initState() {
    super.initState();
    warmUpApiServer();
    _initCamera();
  }

  @override
  void dispose() {
    _safeStopImageStream();
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  // ================= CAMERA =================
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();
      await _controller!.setExposureMode(ExposureMode.auto);
      await _controller!.setFocusMode(FocusMode.auto);

      if (!mounted) return;

      setState(() => _instruction = "Look Straight");
      await _controller!.startImageStream(_processCameraImage);
      _isStreaming = true;
    } catch (e) {
      debugPrint("Camera Init Error: $e");
    }
  }

  Future<void> _safeStopImageStream() async {
    if (_controller != null && _isStreaming) {
      await _controller!.stopImageStream();
      _isStreaming = false;
    }
  }

  // ================= IMAGE STREAM =================
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isProcessing || _isCapturing || _isImageClicked) return;
    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        _updateStatus("No face detected", false);
      } else {
        _checkLiveness(faces.first);
      }
    } catch (e) {
      debugPrint("Error processing face: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // ================= LIVENESS LOGIC =================
  void _checkLiveness(Face face) async {
    final rotY = face.headEulerAngleY ?? 0;
    final rotZ = face.headEulerAngleZ ?? 0;

    if (rotZ.abs() > 25) {
      _updateStatus("Keep head level", false);
      return;
    }

    if (_currentStep == 0) {
      if (rotY.abs() < 10 && !_isCapturing) {
        _isCapturing = true;
        _updateStatus("Hold still...", true);
        await Future.delayed(const Duration(milliseconds: 300));
        await _captureStraightFace();
      } else if (!_isCapturing) {
        _updateStatus("Look Straight", false);
      }
    } else if (_currentStep == 1) {
      if (rotY < -20) {
        // Turned Left
        setState(() {
          _currentStep = 2;
          _progress = 0.66;
          _instruction = "Turn Right →";
        });
      } else {
        _updateStatus("Turn Left ←", false);
      }
    } else if (_currentStep == 2) {
      if (rotY > 20) {
        // Turned Right
        _isImageClicked = true;
        await _safeStopImageStream();
        setState(() {
          _progress = 1.0;
          _instruction = "Verifying...";
        });
        await _uploadToApi();
      } else {
        _updateStatus("Turn Right →", false);
      }
    }
  }

  void _updateStatus(String msg, bool aligned) {
    if (!mounted) return;
    if (_instruction != msg) {
      setState(() {
        _instruction = msg;
        _isFaceAligned = aligned;
      });
    }
  }

  // ================= CAPTURE =================
  Future<void> _captureStraightFace() async {
    try {
      await _safeStopImageStream();

      final file = await _controller!.takePicture();
      final rawBytes = await file.readAsBytes();

      _capturedImageBytes = rawBytes;

      if (!mounted) return;

      setState(() {
        _currentStep = 1;
        _progress = 0.33;
        _instruction = "Turn Left ←";
      });

      await _controller!.startImageStream(_processCameraImage);
      _isStreaming = true;
    } catch (e) {
      debugPrint("Capture Error: $e");
      _reset();
    } finally {
      _isCapturing = false;
    }
  }

  // ================= API =================
  Future<void> _uploadToApi() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/register"),
      );

      request.fields['admission_no'] = widget.admissionNo;
      request.fields['auth_uid'] = user.uid;

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          _capturedImageBytes!,
          filename: 'face.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final response = await http.Response.fromStream(
        await request.send().timeout(
          const Duration(seconds: _apiTimeoutSeconds),
        ),
      );

      debugPrint("API Status: ${response.statusCode} | ${response.body}");

      if (response.statusCode == 200 ||
          (response.statusCode == 400 &&
              response.body.toLowerCase().contains("already"))) {
        await _markFaceEnabled();
      } else if (response.statusCode == 400 &&
          response.body.contains("Only JPG")) {
        _handleError("Server rejected format. Retrying...");
      } else {
        _handleError("Server Error: ${response.body}");
      }
    } catch (e) {
      _handleError("Connection Error: $e");
    }
  }

  // ================= HELPERS =================
  Future<void> _markFaceEnabled() async {
    try {
      await FirebaseFirestore.instance
          .collection('student')
          .doc(widget.admissionNo)
          .update({
            'face_enabled': true,
            'face_registered_at': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Face Registered Successfully! Redirecting..."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(seconds: 2));

      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _goToLogin();
    } catch (e) {
      _handleError("Database Error: $e");
    }
  }

  void _handleError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    _reset();
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _currentStep = 0;
      _progress = 0.0;
      _isImageClicked = false;
      _capturedImageBytes = null;
      _instruction = "Look Straight";
    });
    _initCamera();
  }

  void _goToLogin() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final plane = image.planes.first;
    final rotation =
        InputImageRotationValue.fromRawValue(
          _controller!.description.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    // 1. Loading State
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF2196F3),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Initializing Camera...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Main Camera UI
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A. Camera Preview
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),

          // B. Light Blue Overlay (Hole Effect)
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color(0xFF2196F3).withOpacity(0.3),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    height: 300,
                    width: 300,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // C. Custom Circle Border
          Center(
            child: Container(
              height: 320,
              width: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isFaceAligned ? Colors.greenAccent : Colors.white54,
                  width: 4,
                ),
                boxShadow: [
                  if (_isFaceAligned)
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                ],
              ),
            ),
          ),

          // D. Top Bar (With Back Arrow)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  children: [
                    // ✅ FIXED: Back Arrow instead of Logout
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _goToLogin,
                    ),
                    const Expanded(
                      child: Text(
                        "Face Registration",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.black45,
                              offset: Offset(2.0, 2.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Balance spacing
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "Hello, ${widget.studentName}",
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white30,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isFaceAligned ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),

          // E. Bottom Instruction Card
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isFaceAligned
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isFaceAligned
                          ? Icons.check_circle_outline
                          : Icons.face_retouching_natural,
                      color: _isFaceAligned ? Colors.green : Colors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _instruction,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (_isProcessing)
                          const Text(
                            "Processing...",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

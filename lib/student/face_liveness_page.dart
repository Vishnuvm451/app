import 'dart:async';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/auth/api_warmup.dart';
import 'package:darzo/auth/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;

import 'package:darzo/widget/face_camera_circle.dart';

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
  static const int _apiTimeoutSeconds = 120;

  CameraController? _controller;

  bool _isStreaming = false;
  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _isImageClicked = false;
  bool _torchEnabled = false;

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

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) => _goToLogin(),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF1565C0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _appBar(),
                const SizedBox(height: 16),

                Text(
                  "Hello, ${widget.studentName}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // 🔵 BIG CAMERA CIRCLE
                Expanded(
                  child: Center(
                    child: _controller == null
                        ? const CircularProgressIndicator(color: Colors.white)
                        : FaceCameraCircle(
                            controller: _controller!,
                            progress: _progress,
                            isFaceAligned: _isFaceAligned,
                            size: 280,
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // 📊 PROGRESS INDICATOR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 6,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _isFaceAligned ? Colors.greenAccent : Colors.orangeAccent,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ⚠️ INSTRUCTION PANEL
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isFaceAligned
                              ? Icons.check_circle
                              : Icons.warning_amber_rounded,
                          color: _isFaceAligned ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _instruction,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _goToLogin,
          ),
          const Spacer(),
          const Text(
            "Face Liveness Check",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // ================= CAMERA INIT =================
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
    } catch (e, s) {
      debugPrint("❌ CAMERA INIT ERROR: $e");
      debugPrintStack(stackTrace: s);
      if (mounted) setState(() => _instruction = "Camera error");
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
    if (_controller == null || _isProcessing || _isCapturing || _isImageClicked)
      return;

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
    } catch (e, s) {
      debugPrint("❌ FACE PROCESS ERROR: $e");
      debugPrintStack(stackTrace: s);
    } finally {
      _isProcessing = false;
    }
  }

  // ================= LIVENESS =================
  void _checkLiveness(Face face) async {
    final rotY = face.headEulerAngleY ?? 0;
    final rotZ = face.headEulerAngleZ ?? 0;

    // ✅ FIX 1: Safe flash mode with error handling
    if (!_torchEnabled && face.boundingBox.height < 120) {
      try {
        await _controller?.setFlashMode(FlashMode.torch);
        _torchEnabled = true;
      } catch (_) {
        debugPrint("⚠️ Torch not available on this device");
      }
    }

    // ✅ FIX 2: Head tilt validation
    if (rotZ.abs() > 25) {
      _updateStatus("Keep head level", false);
      return;
    }

    switch (_currentStep) {
      case 0:
        // ✅ FIX 3: Straight face capture
        if (rotY.abs() < 10 && !_isCapturing) {
          _isCapturing = true;
          _updateStatus("Hold still...", true);
          await Future.delayed(const Duration(milliseconds: 300));
          await _captureStraightFace();
        } else {
          _updateStatus("Look Straight", false);
        }
        break;

      case 1:
        // ✅ FIX 4: Turn LEFT first (rotY < -20 means left)
        if (rotY < -20) {
          setState(() {
            _currentStep = 2;
            _progress = 0.66;
            _instruction = "Turn Right →";
            _isFaceAligned = false;
          });
        } else {
          _updateStatus("Turn Left ←", false);
        }
        break;

      case 2:
        // ✅ FIX 5: Turn RIGHT last (rotY > 20 means right)
        if (rotY > 20) {
          setState(() {
            _progress = 1.0;
            _instruction = "Verifying...";
            _isImageClicked = true;
          });

          await _safeStopImageStream();
          try {
            await _controller?.setFlashMode(FlashMode.off);
          } catch (_) {}

          await _uploadToApi();
        } else {
          _updateStatus("Turn Right →", false);
        }
        break;
    }
  }

  void _updateStatus(String msg, bool aligned) {
    if (_instruction != msg && mounted) {
      setState(() {
        _instruction = msg;
        _isFaceAligned = aligned;
      });
    }
  }

  // ================= CAPTURE =================
  Future<void> _captureStraightFace() async {
    // ✅ FIX 6: Check if image already captured
    if (_capturedImageBytes != null) {
      _isCapturing = false;
      return;
    }

    try {
      await _safeStopImageStream();
      final XFile file = await _controller!.takePicture();
      final rawBytes = await file.readAsBytes();
      final decoded = img.decodeImage(rawBytes);

      if (decoded == null) {
        throw Exception("Image decode failed");
      }

      final jpegBytes = img.encodeJpg(decoded, quality: 90);
      _capturedImageBytes = Uint8List.fromList(jpegBytes);

      if (!mounted) return;

      setState(() {
        _currentStep = 1;
        _progress = 0.33;
        _instruction = "Turn Left ←";
        _isFaceAligned = false;
      });

      await _controller!.startImageStream(_processCameraImage);
      _isStreaming = true;
    } catch (e, s) {
      debugPrint("❌ CAPTURE ERROR: $e");
      debugPrintStack(stackTrace: s);
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
      // ================= HEALTH CHECK =================
      try {
        final health = await http
            .get(Uri.parse("$_apiBaseUrl/health"))
            .timeout(const Duration(seconds: 10));

        if (health.statusCode != 200) {
          debugPrint("⚠️ Health check failed, proceeding anyway");
        }
      } catch (e) {
        debugPrint("⚠️ Health check error: $e, proceeding anyway");
      }

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
        ),
      );

      final response = await http.Response.fromStream(
        await request.send().timeout(
          const Duration(seconds: _apiTimeoutSeconds),
        ),
      );

      debugPrint("API STATUS: ${response.statusCode}");
      debugPrint("API BODY: ${response.body}");

      // ================= SUCCESS CASE =================
      if (response.statusCode == 200) {
        await _markFaceEnabled();
        return;
      }

      // ✅ FIX 7: Fixed logic operator (should be || not &&)
      if ((response.statusCode == 400 || response.statusCode == 409) &&
          response.body.toLowerCase().contains("already")) {
        debugPrint("ℹ️ Face already registered — treating as success");
        await _markFaceEnabled();
        return;
      }

      // ================= REAL FAILURE =================
      throw Exception(response.body);
    } on TimeoutException catch (e) {
      debugPrint("❌ REGISTER FAILED: TimeoutException");
      debugPrint(e.toString());
      _handleError("Server timeout. Try again.");
    } catch (e) {
      debugPrint("❌ REGISTER FAILED:");
      debugPrint(e.toString());
      _handleError(e.toString());
    }
  }

  // ================= HELPER =================
  Future<void> _markFaceEnabled() async {
    await FirebaseFirestore.instance
        .collection('student')
        .doc(widget.admissionNo)
        .update({
          'face_enabled': true,
          'face_registered_at': FieldValue.serverTimestamp(),
        });

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    _goToLogin();
  }

  // ================= ERROR =================
  void _handleError(String msg) {
    if (!mounted) {
      debugPrint("⚠️ Widget unmounted, skipping UI error");
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));

    _reset();
  }

  void _reset() {
    if (!mounted) return;
    setState(() {
      _currentStep = 0;
      _progress = 0;
      _instruction = "Look Straight";
      _isImageClicked = false;
      _isCapturing = false;
      _capturedImageBytes = null;
      _torchEnabled = false;
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

  // ================= ML INPUT =================
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
}

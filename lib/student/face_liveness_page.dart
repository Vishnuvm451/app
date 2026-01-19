import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/auth/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;

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
  // 🔧 CONFIG
  static const String _apiBaseUrl = "https://darzo-api.onrender.com";
  static const int _apiTimeoutSeconds = 20;

  // 🚀 OPTIMIZED THRESHOLDS (3X FASTER)
  static const int _frameThrottleMs = 50;
  static const double _minFaceSize = 0.05;
  static const double _faceSizeThreshold = 0.05;
  static const double _faceMargin = 25.0;
  static const double _headAngleTolerance = 30.0;

  // CAMERA & ML
  CameraController? _controller;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: _minFaceSize,
    ),
  );

  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _isCameraStopping = false;
  DateTime? _lastFrameTime;

  // FACE DETECTION STATE
  String _instruction = "Position your face in the circle";
  Color _statusColor = Colors.white;
  bool _faceProperlyAligned = false;
  double? _previousFaceWidth;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  // ===================================================
  // 1. INITIALIZE CAMERA
  // ===================================================
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      if (!mounted) return;

      setState(() => _isCameraInitialized = true);

      try {
        await _controller!
            .startImageStream(_processCameraImage)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException("Camera stream startup timeout");
              },
            );
      } catch (e) {
        print("Stream startup error: $e");
        if (mounted) {
          setState(() => _instruction = "Camera stream failed");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _instruction = "Camera initialization failed");
      }
      print("Camera init error: $e");
    }
  }

  // ===================================================
  // 2. CAMERA FRAME PROCESSING (FACE DETECTION ONLY)
  // ===================================================
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isCameraStopping || _isProcessing || _isCapturing) return;

    // Throttle frames
    final now = DateTime.now();
    if (_lastFrameTime != null &&
        now.difference(_lastFrameTime!) <
            Duration(milliseconds: _frameThrottleMs)) {
      return;
    }
    _lastFrameTime = now;

    _isProcessing = true;

    InputImage? inputImage;
    try {
      inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) {
        _isProcessing = false;
        return;
      }

      if (faces.isEmpty) {
        _updateFeedback("📷 No face detected", Colors.redAccent);
        _faceProperlyAligned = false;
      } else if (faces.length > 1) {
        _updateFeedback("⚠️ Only one person at a time", Colors.redAccent);
        _faceProperlyAligned = false;
      } else {
        _checkFaceAlignment(
          faces.first,
          image.width.toDouble(),
          image.height.toDouble(),
        );
      }
    } catch (e) {
      print("Face detection error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  void _updateFeedback(String msg, Color color) {
    if (!mounted || _instruction == msg) return;
    setState(() {
      _instruction = msg;
      _statusColor = color;
    });
  }

  // ===================================================
  // 3. FACE ALIGNMENT CHECK (NO BLINK DETECTION)
  // ===================================================
  void _checkFaceAlignment(Face face, double imgWidth, double imgHeight) {
    final box = face.boundingBox;

    // Check alignment
    if (box.left < _faceMargin ||
        box.top < _faceMargin ||
        box.right > imgWidth - _faceMargin ||
        box.bottom > imgHeight - _faceMargin) {
      _updateFeedback("📍 Keep face in view", Colors.orangeAccent);
      _faceProperlyAligned = false;
      return;
    }

    // Check face size
    if (!_checkFaceSize(box.width, imgWidth)) {
      _faceProperlyAligned = false;
      return;
    }

    // Check head pose
    final headYaw = (face.headEulerAngleY ?? 0).abs();
    final headRoll = (face.headEulerAngleZ ?? 0).abs();

    if (headYaw > _headAngleTolerance || headRoll > _headAngleTolerance) {
      _updateFeedback("🧠 Look straight ahead", Colors.orangeAccent);
      _faceProperlyAligned = false;
      return;
    }

    // Face is properly aligned
    _faceProperlyAligned = true;
    _updateFeedback("✓ Face detected - Ready to capture", Colors.greenAccent);
  }

  // Face size check with movement detection
  bool _checkFaceSize(double faceWidth, double imgWidth) {
    final threshold = imgWidth * _faceSizeThreshold;

    if (faceWidth < threshold) {
      _updateFeedback("📏 Move closer", Colors.orangeAccent);
      return false;
    }

    // Check for sudden movement (prevents blurry capture)
    if (_previousFaceWidth != null) {
      final change = (faceWidth - _previousFaceWidth!).abs();
      final changePercent = change / _previousFaceWidth!;

      if (changePercent > 0.35) {
        _updateFeedback("📸 Hold still", Colors.orangeAccent);
        return false;
      }
    }

    _previousFaceWidth = faceWidth;
    return true;
  }

  // ===================================================
  // 4. MANUAL CAPTURE (BUTTON TRIGGERED)
  // ===================================================
  Future<void> _manualCapture() async {
    if (_isCapturing) return;
    if (!_faceProperlyAligned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Please align your face first"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    _isCapturing = true;
    _isCameraStopping = true;

    try {
      // Proper null check and stream handling
      if (_controller == null || !_controller!.value.isInitialized) {
        throw Exception("Camera not initialized");
      }

      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      await Future.delayed(const Duration(milliseconds: 50));

      if (!mounted) {
        _isCapturing = false;
        _isCameraStopping = false;
        return;
      }

      setState(() => _instruction = "Capturing...");

      // Capture high-res image
      final XFile imageFile = await _controller!.takePicture();
      final imageBytes = await imageFile.readAsBytes();

      await _uploadFaceToBackend(imageBytes);
    } catch (e) {
      print("Capture error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Capture failed: ${e.toString()}"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        _resetCamera();
      }
    }
  }

  Future<void> _resetCamera() async {
    if (!mounted) return;

    setState(() {
      _isCapturing = false;
      _isCameraStopping = false;
      _instruction = "Position your face in the circle";
      _statusColor = Colors.white;
      _faceProperlyAligned = false;
      _previousFaceWidth = null;
    });

    if (_controller != null && _controller!.value.isInitialized) {
      try {
        await _controller!.startImageStream(_processCameraImage);
      } catch (e) {
        print("Stream restart error: $e");
      }
    }
  }

  // ===================================================
  // 5. UPLOAD TO BACKEND
  // ===================================================
  Future<void> _uploadFaceToBackend(Uint8List imageBytes) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _navigateToLogin("Session expired. Please login again.");
      return;
    }

    try {
      if (!mounted) return;

      setState(() => _instruction = "Uploading...");

      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/register"),
      );

      request.fields['admission_no'] = widget.admissionNo;
      request.fields['auth_uid'] = user.uid;
      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: 'face.jpg'),
      );

      // Proper timeout with error handling
      late http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await request.send().timeout(
          Duration(seconds: _apiTimeoutSeconds),
          onTimeout: () {
            throw TimeoutException(
              "Upload timed out after ${_apiTimeoutSeconds}s",
            );
          },
        );
      } on TimeoutException catch (e) {
        throw Exception("Connection timeout: ${e.message}");
      }

      final response = await http.Response.fromStream(streamedResponse);

      // Better error handling for non-200 responses
      if (response.statusCode != 200) {
        String errorMessage = "Server error: ${response.statusCode}";
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? errorMessage;
        } catch (_) {
          // Use default error message
        }
        throw Exception(errorMessage);
      }

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('student')
          .doc(widget.admissionNo)
          .update({
            'face_enabled': true,
            'face_registered_at': FieldValue.serverTimestamp(),
          });

      // Logout and navigate
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      _navigateToLogin("✓ Face registered successfully!");
    } catch (e) {
      print("Upload error: $e");

      if (!mounted) return;

      setState(() {
        _isCapturing = false;
        _isCameraStopping = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      await _resetCamera();
    }
  }

  // Proper navigation with delay
  void _navigateToLogin(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.contains("✓") ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );

    // Wait for SnackBar to display
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    });
  }

  // ===================================================
  // 6. IMAGE CONVERSION (PLATFORM-AWARE)
  // ===================================================
  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_controller == null) return null;

    final camera = _controller!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation rotation = InputImageRotation.rotation0deg;
    if (Platform.isAndroid) {
      final rotationCompensation = (sensorOrientation + 270) % 360;
      rotation =
          InputImageRotationValue.fromRawValue(rotationCompensation) ??
          InputImageRotation.rotation0deg;
    } else {
      final rotationCompensation = (sensorOrientation + 90) % 360;
      rotation =
          InputImageRotationValue.fromRawValue(rotationCompensation) ??
          InputImageRotation.rotation0deg;
    }

    final format = Platform.isAndroid
        ? InputImageFormat.nv21
        : InputImageFormat.bgra8888;

    if (image.planes.isEmpty) return null;

    return InputImage.fromBytes(
      bytes: _concatenatePlanes(image.planes),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final buffer = WriteBuffer();
    for (final plane in planes) {
      buffer.putUint8List(plane.bytes);
    }
    return buffer.done().buffer.asUint8List();
  }

  // ===================================================
  // 7. BUILD UI (NEW DESIGN WITH CAPTURE BUTTON)
  // ===================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _navigateToLogin("Registration Cancelled");
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2196F3),
        appBar: AppBar(
          title: const Text("Face Registration"),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => _navigateToLogin("Cancelled"),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      "Welcome, ${widget.studentName}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _instruction,
                        style: TextStyle(
                          color: _statusColor == Colors.white
                              ? Colors.white
                              : _statusColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

              // Camera Circle with Face Detection Border
              Expanded(
                child: Center(
                  child: SizedBox(
                    height: 340,
                    width: 340,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Camera Preview
                        ClipOval(
                          child: SizedBox(
                            height: 340,
                            width: 340,
                            child: _isCameraInitialized
                                ? FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _controller!
                                          .value
                                          .previewSize!
                                          .height,
                                      height:
                                          _controller!.value.previewSize!.width,
                                      child: CameraPreview(_controller!),
                                    ),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        // Dynamic Border (Green when aligned, White when not)
                        Container(
                          height: 340,
                          width: 340,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _faceProperlyAligned
                                  ? Colors.greenAccent
                                  : Colors.white,
                              width: 6,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (_faceProperlyAligned
                                            ? Colors.greenAccent
                                            : Colors.white)
                                        .withOpacity(0.4),
                                blurRadius: 25,
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                        ),

                        // Capturing Overlay
                        if (_isCapturing)
                          Container(
                            height: 340,
                            width: 340,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    "Registering face...",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Capture Button Section
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Capture Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isCapturing ? null : _manualCapture,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _faceProperlyAligned
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          foregroundColor: const Color(0xFF2196F3),
                          disabledBackgroundColor: Colors.white.withOpacity(
                            0.3,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 8,
                        ),
                        icon: Icon(
                          _isCapturing ? Icons.hourglass_top : Icons.camera_alt,
                          size: 24,
                        ),
                        label: Text(
                          _isCapturing ? "Registering..." : "CAPTURE PHOTO",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Helper Text
                    Text(
                      _faceProperlyAligned
                          ? "✓ Face aligned - Ready to capture"
                          : "Align face in circle to enable capture",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  // ================= CONFIG =================
  static const String _apiBaseUrl = "https://darzo-backend-api.onrender.com";
  static const int _apiTimeoutSeconds = 60;

  // ================= CAMERA & ML =================
  CameraController? _controller;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableLandmarks: true,
      enableClassification: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.2,
    ),
  );

  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _isImageClicked = false;
  bool _isLoadingData = true;
  bool _torchEnabled = false;

  // ================= LIVENESS UI =================
  int _currentStep = 0;
  double _progress = 0.0;
  String _instruction = "Initializing...";
  bool _isFaceAligned = false;

  // ================= DATA =================
  Uint8List? _capturedImageBytes;

  String? studentId;
  String? studentDocId;
  String? admissionNo;
  String? classId;
  String? sessionType;

  String? _errorMessage;

  // ================= LIFECYCLE =================
  @override
  void initState() {
    super.initState();
    _loadDataAndCamera();
  }

  @override
  void dispose() {
    _safeStopStream();
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  // ================= SAFE STREAM STOP =================
  Future<void> _safeStopStream() async {
    if (_controller != null && _controller!.value.isStreamingImages) {
      await _controller!.stopImageStream();
    }
  }

  // ================= LOAD DATA & CAMERA =================
  Future<void> _loadDataAndCamera() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not logged in";

      studentId = user.uid;

      final studentQuery = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: studentId)
          .limit(1)
          .get();

      if (studentQuery.docs.isEmpty) throw "Student profile not found";

      final doc = studentQuery.docs.first;
      final data = doc.data();

      studentDocId = doc.id;
      admissionNo = data['admissionNo'] ?? doc.id;
      classId = data['classId'];

      if (classId == null) throw "Class not assigned";

      final sessionQuery = await FirebaseFirestore.instance
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionQuery.docs.isEmpty) throw "No active session";

      sessionType = sessionQuery.docs.first['sessionType'];

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

      setState(() {
        _isLoadingData = false;
        _instruction = "Look Straight";
      });

      await _controller!.startImageStream(_processCameraImage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        _errorMessage = e.toString();
      });
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

    // Torch logic
    if (!_torchEnabled && face.boundingBox.height < 120) {
      try {
        await _controller?.setFlashMode(FlashMode.torch);
        _torchEnabled = true;
      } catch (_) {
        debugPrint("⚠️ Torch not available on this device");
      }
    }

    // Head tilt validation
    if (rotZ.abs() > 25) {
      _updateStatus("Keep head level", false);
      return;
    }

    switch (_currentStep) {
      case 0:
        if (rotY.abs() < 10 && !_isCapturing) {
          _isCapturing = true;
          _updateStatus("Hold still...", true);
          await Future.delayed(const Duration(milliseconds: 300));
          await _captureFace();
        } else {
          _updateStatus("Look Straight", false);
        }
        break;

      case 1:
        // Turn LEFT
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
        // Turn RIGHT
        if (rotY > 20) {
          setState(() {
            _progress = 1.0;
            _isImageClicked = true;
            _instruction = "Verifying...";
          });

          await _safeStopStream();
          try {
            await _controller?.setFlashMode(FlashMode.off);
          } catch (_) {}

          await _verifyAndMark();
        } else {
          _updateStatus("Turn Right →", false);
        }
        break;
    }
  }

  void _updateStatus(String msg, bool aligned) {
    if (!mounted || _instruction == msg) return;
    setState(() {
      _instruction = msg;
      _isFaceAligned = aligned;
    });
  }

  // ================= CAPTURE =================
  Future<void> _captureFace() async {
    if (_capturedImageBytes != null) {
      _isCapturing = false;
      return;
    }

    try {
      await _safeStopStream();
      final file = await _controller!.takePicture();
      _capturedImageBytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _currentStep = 1;
        _progress = 0.33;
        _instruction = "Turn Left ←";
        _isFaceAligned = false;
      });

      await _controller!.startImageStream(_processCameraImage);
    } catch (e, s) {
      debugPrint("❌ CAPTURE ERROR: $e");
      debugPrintStack(stackTrace: s);
      _resetFlow();
    } finally {
      _isCapturing = false;
    }
  }

  // ================= VERIFY & MARK =================
  Future<void> _verifyAndMark() async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/verify"),
      );

      request.fields['admission_no'] = admissionNo!;

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

      if (response.body.isEmpty) {
        _handleError("Empty server response");
        return;
      }

      final data = jsonDecode(response.body);

      if (response.statusCode != 200 || data['success'] != true) {
        _handleError(data['message'] ?? "Face verification failed");
        return;
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']), backgroundColor: Colors.green),
      );

      await _markAttendance();
    } on TimeoutException catch (e) {
      debugPrint("❌ VERIFICATION FAILED: TimeoutException");
      debugPrint(e.toString());
      _handleError("Server timeout. Try again.");
    } catch (e, s) {
      debugPrint("❌ VERIFICATION FAILED: $e");
      debugPrintStack(stackTrace: s);
      _handleError("Verification failed");
    }
  }

  Future<void> _markAttendance() async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final docId = "${classId}_${today}_$sessionType";

      final ref = FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .collection('student')
          .doc(studentDocId);

      final snap = await ref.get();

      if (!snap.exists) {
        await ref.set({
          'studentId': studentId,
          'admissionNo': admissionNo,
          'status': 'present',
          'method': 'face',
          'markedAt': FieldValue.serverTimestamp(),
        });
      }

      _showSuccess();
    } catch (e, s) {
      debugPrint("❌ MARK ATTENDANCE ERROR: $e");
      debugPrintStack(stackTrace: s);
      _handleError("Failed to mark attendance");
    }
  }

  // ================= ERROR & RESET =================
  void _handleError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    _resetFlow();
  }

  void _resetFlow() {
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
    _controller?.startImageStream(_processCameraImage);
  }

  void _showSuccess() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: const Text(
          "Attendance marked successfully!",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Done", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ================= ML KIT INPUT =================
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
    if (_isLoadingData) {
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

    // 2. Error State
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF2196F3),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 50),
                const SizedBox(height: 20),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoadingData = true;
                      _errorMessage = null;
                    });
                    _loadDataAndCamera();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                  ),
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. Main Camera UI
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // A. Camera Preview
          if (_controller != null && _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),

          // B. Overlay (Light blue tint outside the circle)
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              // 🔥 CHANGE: Light blue with low opacity
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

          // C. Custom Circle Border (Animated Color)
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

          // D. Top Bar (Progress & Title)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // Back Button & Title
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        "Liveness Check",
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
                    const SizedBox(width: 40), // Balance the back button
                  ],
                ),
                const SizedBox(height: 20),
                // Step Progress Bar
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
                  // Dynamic Icon based on instruction
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
                  // Instruction Text
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

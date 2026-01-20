import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  // 🔧 CONFIG
  static const String _apiBaseUrl = "https://darzo-api.onrender.com";
  static const int _apiTimeoutSeconds = 15;

  // 🚀 OPTIMIZED THRESHOLDS
  static const int _frameThrottleMs = 50;
  static const double _minFaceSize = 0.05;
  static const double _faceSizeThreshold = 0.05;
  static const double _faceMargin = 25.0;
  static const double _headAngleTolerance = 30.0;

  // STATE
  bool isLoading = true;
  bool isSessionActive = false;
  String? errorMessage;

  // Student Data
  String? studentId;
  String? studentDocId;
  String? admissionNo;
  String? classId;

  // Session Details
  DocumentSnapshot? activeSession;
  String? sessionType;

  // Camera & ML
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
  bool _isProcessingFrame = false;
  bool _isVerifying = false;
  bool _isCameraStopping = false;
  DateTime? _lastFrameTime;

  // Face Detection State
  String _instruction = "Position your face in the circle";
  Color _statusColor = Colors.white;
  bool _faceProperlyAligned = false;
  double? _previousFaceWidth;

  @override
  void initState() {
    super.initState();
    _loadDataAndCamera();
  }

  @override
  void dispose() {
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  // ===================================================
  // 1. LOAD DATA + CAMERA
  // ===================================================
  Future<void> _loadDataAndCamera() async {
    try {
      studentId = FirebaseAuth.instance.currentUser?.uid;
      if (studentId == null) throw "User not logged in";

      // Load student profile
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: studentId)
          .limit(1)
          .get()
          .then(
            (q) => q.docs.isNotEmpty
                ? q.docs.first
                : throw "Student profile not found",
          );

      final data = doc.data() as Map<String, dynamic>;
      classId = data['classId'];
      admissionNo = data['admissionNo'] ?? doc.id;
      studentDocId = doc.id;

      if (classId == null) throw "Class ID not assigned";

      // Check for active session
      final sessionQuery = await FirebaseFirestore.instance
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionQuery.docs.isNotEmpty) {
        activeSession = sessionQuery.docs.first;
        sessionType = activeSession!['sessionType'];

        if (sessionType == null ||
            (sessionType != 'morning' && sessionType != 'afternoon')) {
          throw "Invalid session type received: $sessionType";
        }

        isSessionActive = true;
      } else {
        _instruction = "No Active Session";
        _statusColor = Colors.orangeAccent;
      }

      // Initialize camera
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

      if (isSessionActive) {
        await _controller!.startImageStream(_processCameraImage);
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = e.toString());
      }
      print("Init Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ===================================================
  // 2. CAMERA FRAME PROCESSING
  // ===================================================
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isCameraStopping ||
        _isProcessingFrame ||
        _isVerifying ||
        !isSessionActive)
      return;

    final now = DateTime.now();
    if (_lastFrameTime != null &&
        now.difference(_lastFrameTime!) <
            Duration(milliseconds: _frameThrottleMs)) {
      return;
    }
    _lastFrameTime = now;

    _isProcessingFrame = true;

    InputImage? inputImage;
    try {
      inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      if (!mounted) {
        _isProcessingFrame = false;
        return;
      }

      if (faces.isEmpty) {
        _updateStatus("📷 No face detected", Colors.redAccent);
        _faceProperlyAligned = false;
      } else if (faces.length > 1) {
        _updateStatus("⚠️ Only one person at a time", Colors.redAccent);
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
      _isProcessingFrame = false;
    }
  }

  void _updateStatus(String msg, Color color) {
    if (!mounted || _instruction == msg) return;
    setState(() {
      _instruction = msg;
      _statusColor = color;
    });
  }

  // ===================================================
  // 3. FACE ALIGNMENT CHECK
  // ===================================================
  void _checkFaceAlignment(Face face, double imgWidth, double imgHeight) {
    final box = face.boundingBox;

    if (box.left < _faceMargin ||
        box.top < _faceMargin ||
        box.right > imgWidth - _faceMargin ||
        box.bottom > imgHeight - _faceMargin) {
      _updateStatus("📍 Keep face in view", Colors.orangeAccent);
      _faceProperlyAligned = false;
      return;
    }

    if (!_checkFaceSize(box.width, imgWidth)) {
      _faceProperlyAligned = false;
      return;
    }

    final headYaw = (face.headEulerAngleY ?? 0).abs();
    final headRoll = (face.headEulerAngleZ ?? 0).abs();

    if (headYaw > _headAngleTolerance || headRoll > _headAngleTolerance) {
      _updateStatus("🧠 Look straight ahead", Colors.orangeAccent);
      _faceProperlyAligned = false;
      return;
    }

    _faceProperlyAligned = true;
    _updateStatus("✓ Face detected - Ready to mark", Colors.greenAccent);
  }

  bool _checkFaceSize(double faceWidth, double imgWidth) {
    final threshold = imgWidth * _faceSizeThreshold;

    if (faceWidth < threshold) {
      _updateStatus("📏 Move closer", Colors.orangeAccent);
      return false;
    }

    if (_previousFaceWidth != null) {
      final change = (faceWidth - _previousFaceWidth!).abs();
      final changePercent = change / _previousFaceWidth!;

      if (changePercent > 0.35) {
        _updateStatus("📸 Hold still", Colors.orangeAccent);
        return false;
      }
    }

    _previousFaceWidth = faceWidth;
    return true;
  }

  // ===================================================
  // 4. MANUAL CAPTURE
  // ===================================================
  Future<void> _manualCapture() async {
    if (_isVerifying) return;
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

    _isVerifying = true;
    _isCameraStopping = true;

    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        throw "Camera not initialized";
      }

      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }

      await Future.delayed(const Duration(milliseconds: 50));

      if (!mounted) {
        _isVerifying = false;
        _isCameraStopping = false;
        return;
      }

      setState(() => _instruction = "Scanning face...");

      final XFile imageFile = await _controller!.takePicture();
      final imageBytes = await imageFile.readAsBytes();

      await _verifyAndMarkAttendance(imageBytes);
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
      _isVerifying = false;
      _isCameraStopping = false;
      _instruction = "Position your face in the circle";
      _statusColor = Colors.white;
      _faceProperlyAligned = false;
      _previousFaceWidth = null;
    });

    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.isStreamingImages) {
      try {
        await _controller!.startImageStream(_processCameraImage);
      } catch (e) {
        print("Stream restart error: $e");
      }
    }
  }

  // ===================================================
  // 5. VERIFY FACE
  // ===================================================
  Future<void> _verifyAndMarkAttendance(Uint8List imageBytes) async {
    try {
      if (!mounted) return;
      setState(() => _instruction = "Verifying face...");

      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/verify"),
      );

      request.files.add(
        http.MultipartFile.fromBytes('image', imageBytes, filename: 'face.jpg'),
      );

      late http.StreamedResponse streamedResponse;
      try {
        streamedResponse = await request.send().timeout(
          Duration(seconds: _apiTimeoutSeconds),
          onTimeout: () {
            throw TimeoutException(
              "Verification timed out after ${_apiTimeoutSeconds}s",
            );
          },
        );
      } on TimeoutException catch (e) {
        throw Exception("Connection timeout: ${e.message}");
      }

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        String errorMessage = "Verification failed: ${response.statusCode}";
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? errorMessage;
        } catch (_) {}
        throw Exception(errorMessage);
      }

      late final Map<String, dynamic> result;
      try {
        result = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw Exception("Invalid API response format");
      }

      final matchedAdmission = result['admissionNo'].toString();

      if (matchedAdmission != admissionNo) {
        throw Exception(
          "Face mismatch! Expected: $admissionNo, Got: $matchedAdmission",
        );
      }

      await _markAttendanceFirestore();
    } catch (e) {
      print("Verification error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Error: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      await _resetCamera();
    }
  }

  // ===================================================
  // 6. MARK ATTENDANCE (FIXED DATE MATCHING)
  // ===================================================
  Future<void> _markAttendanceFirestore() async {
    try {
      if (activeSession == null) {
        throw "Session is no longer available";
      }

      if (sessionType == null) {
        throw "Session type is not available";
      }

      // ✅ FIXED: Removed .toUtc() to match Teacher's Local Date ID
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final specificSessionId = "${classId}_${today}_$sessionType";

      // Verify session is still active
      final sessionDoc = await FirebaseFirestore.instance
          .collection('attendance_session')
          .doc(specificSessionId)
          .get();

      if (!sessionDoc.exists || sessionDoc['isActive'] != true) {
        throw "Attendance session has ended";
      }

      bool alreadyMarked = false;
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final docRef = FirebaseFirestore.instance
            .collection('attendance')
            .doc(specificSessionId)
            .collection('student')
            .doc(studentDocId);

        final snap = await transaction.get(docRef);
        alreadyMarked = snap.exists;

        if (!snap.exists) {
          transaction.set(docRef, {
            'studentId': studentId,
            'admissionNo': admissionNo,
            'status': 'present',
            'sessionType': sessionType,
            'method': 'face_scan',
            'markedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      if (!mounted) return;
      _showSuccessDialog(alreadyMarked: alreadyMarked);
    } catch (e) {
      print("Attendance error: $e");
      if (mounted) {
        String errorMsg = e.toString();

        if (errorMsg.contains("session has ended") ||
            errorMsg.contains("no longer available")) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("⚠️ Attendance session has ended by teacher"),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to mark attendance: $errorMsg"),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          _resetCamera();
        }
      }
    }
  }

  void _showSuccessDialog({required bool alreadyMarked}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            Icon(
              alreadyMarked ? Icons.info_outline : Icons.check_circle,
              color: alreadyMarked ? Colors.orange : Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              alreadyMarked ? "Already Marked" : "Success! ✓",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          alreadyMarked
              ? "You have already marked attendance for the $sessionType session."
              : "Attendance marked for $sessionType session.",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // 7. IMAGE CONVERSION
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
  // 8. BUILD UI
  // ===================================================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF2196F3),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF2196F3),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: BackButton(
            onPressed: () => Navigator.pop(context),
            color: Colors.white,
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.white),
                const SizedBox(height: 24),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isLoading = true;
                      errorMessage = null;
                    });
                    _loadDataAndCamera();
                  },
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        title: const Text("Mark Attendance"),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
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
                  if (isSessionActive && sessionType != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        "Session: ${sessionType!.toUpperCase()}",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SizedBox(
                  height: 340,
                  width: 340,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipOval(
                        child: SizedBox(
                          height: 340,
                          width: 340,
                          child: _isCameraInitialized
                              ? FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width:
                                        _controller!.value.previewSize!.height,
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
                        ),
                      ),
                      if (_isVerifying)
                        Container(
                          height: 340,
                          width: 340,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isVerifying ? null : _manualCapture,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _faceProperlyAligned
                        ? Colors.white
                        : Colors.white.withOpacity(0.5),
                    foregroundColor: const Color(0xFF2196F3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 8,
                  ),
                  icon: Icon(
                    _isVerifying ? Icons.hourglass_top : Icons.check_circle,
                    size: 24,
                  ),
                  label: Text(
                    _isVerifying ? "Marking..." : "MARK ATTENDANCE",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

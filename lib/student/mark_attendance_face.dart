import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../widget/face_camera_circle.dart';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  // ================= CONFIG =================
  static const String _apiBaseUrl = "https://darzo-backend-api.onrender.com";
  static const int _apiTimeoutSeconds = 120;

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

    // ✅ FIX 1: Safe torch/flash with error handling
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
          await _captureFace();
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
    // ✅ FIX 6: Check if image already captured
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
        ),
      );

      final response = await http.Response.fromStream(
        await request.send().timeout(
          const Duration(seconds: _apiTimeoutSeconds),
        ),
      );

      // ✅ FIX 7: Added check for empty response
      if (response.body.isEmpty) {
        _handleError("Empty server response");
        return;
      }

      final data = jsonDecode(response.body);

      // ✅ FIX 8: Proper null check for data['success']
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
        title: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        content: const Text("Attendance marked successfully"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
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

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: Color(0xFF2196F3),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF2196F3),
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        title: const Text("Mark Attendance"),
        backgroundColor: const Color(0xFF2196F3),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 40),
          Center(
            child: FaceCameraCircle(
              controller: _controller!,
              progress: _progress,
              isFaceAligned: _isFaceAligned,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _instruction,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

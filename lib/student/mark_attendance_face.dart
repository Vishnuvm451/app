import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  // ================= CONFIG =================
  static const String _apiBaseUrl = "https://darzo-backend-api.onrender.com";
  static const int _apiTimeoutSeconds = 30;

  static const int _maxImageSizePerImage = 900 * 1024;
  static const int _totalMaxSize = 3 * 1024 * 1024;
  static const int _jpegQuality = 75;

  // ML Kit Orientation Thresholds (Relaxed slightly for better UX)
  static const double _straightYawLimit = 15.0; // Relaxed from 12.0
  static const double _turnYawThreshold =
      20.0; // Relaxed from 25.0 to make turning easier detected
  static const double _maxTilt = 20.0; // Relaxed from 15.0

  static const int _holdDurationSeconds = 3;
  static const int _maxLivenessSeconds = 60;

  // ================= CAMERA & ML =================
  CameraController? _controller;
  late FaceDetector _faceDetector;
  bool _isCameraInitialized = false;

  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _isSubmitting = false;
  bool _isLoadingData = true;
  bool _isDisposed = false;

  // ================= LIVENESS UI =================
  int _step = 0; // 0=Straight, 1=Left, 2=Right
  double _progress = 0.0;
  String _instruction = "Initializing...";
  bool _faceAligned = false;

  // Face Painting Data
  List<Face> _faces = [];
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;

  // Hold Timer
  DateTime? _holdStartTime;
  int _secondsRemaining = _holdDurationSeconds;
  Timer? _livenessTimeoutTimer;

  // Store Images
  Uint8List? _straight;
  Uint8List? _left;
  Uint8List? _right;

  // ================= DATA =================
  String? studentId;
  String? admissionNo;
  String? classId;
  String? sessionId;
  String? _errorMessage;

  // ================= LIFECYCLE =================
  @override
  void initState() {
    super.initState();

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.10, // chnaged from 0.15 to 0.10 for better detection
      ),
    );

    _startLivenessTimeout();
    _loadDataAndCamera();
  }

  void _startLivenessTimeout() {
    _livenessTimeoutTimer?.cancel();
    _livenessTimeoutTimer = Timer(
      const Duration(seconds: _maxLivenessSeconds),
      () {
        if (mounted && !_isDisposed && !_isSubmitting && _step < 3) {
          _showError("Verification took too long. Please try again.");
          _resetFlow();
        }
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _livenessTimeoutTimer?.cancel();
    _stopStream();
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _stopStream() async {
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
      } catch (e) {
        debugPrint("Stop stream error: $e");
      }
    }
  }

  // ================= LOAD DATA & CAMERA =================
  Future<void> _loadDataAndCamera() async {
    if (_isDisposed) return;

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

      admissionNo = data['admissionNo'] ?? doc.id;
      classId = data['classId'];

      if (classId == null) throw "Class not assigned";

      final sessionQuery = await FirebaseFirestore.instance
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionQuery.docs.isEmpty) {
        throw "No active attendance session for your class";
      }

      sessionId = sessionQuery.docs.first.id;

      final cameras = await availableCameras();
      if (cameras.isEmpty) throw "No cameras available";

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraLensDirection = frontCamera.lensDirection;

      _controller = CameraController(
        frontCamera,
        ResolutionPreset
            .medium, // Changed to medium for better performance/speed
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      _isCameraInitialized = true;

      if (_isDisposed || !mounted) return;

      _rotation =
          InputImageRotationValue.fromRawValue(frontCamera.sensorOrientation) ??
          InputImageRotation.rotation0deg;

      await _controller!.startImageStream(_processFrame);

      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _instruction = "Look Straight 👀";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // ================= FRAME PROCESS =================
  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing ||
        _isCapturing ||
        _isSubmitting ||
        _isDisposed ||
        !mounted) {
      return;
    }

    _isProcessing = true;

    try {
      final input = _toInputImage(image);
      if (input == null) {
        _isProcessing = false;
        return;
      }

      final faces = await _faceDetector.processImage(input);

      if (_isDisposed || !mounted) {
        _isProcessing = false;
        return;
      }

      setState(() {
        _faces = faces;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });

      if (faces.isEmpty) {
        _resetHold("No face detected 🔍");
        _isProcessing = false;
        return;
      }

      final face = faces.first;

      String? qualityError = _checkFaceQuality(face, _imageSize!);
      if (qualityError != null) {
        _resetHold(qualityError);
        _isProcessing = false; // Important: Allow next frame to process
        return;
      }

      _evaluateFace(face);
    } catch (e) {
      debugPrint("Frame error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // ================= CORE FACE MATH =================
  String? _checkFaceQuality(Face face, Size imageSize) {
    final Rect box = face.boundingBox;

    // 1. Check Size (Face must be at least 15% of screen width)
    if (box.width < imageSize.width * 0.15) {
      return "Move Closer 🔍";
    }

    // 2. Face Position Check (Ensure face is somewhat centered, not touching edges)
    // Relaxed margins: 2 pixels instead of 5 to avoid constant errors
    if (box.left < 2 ||
        box.top < 2 ||
        box.right > imageSize.width - 2 ||
        box.bottom > imageSize.height - 2) {
      return "Face Fully in Frame 🖼️";
    }

    return null;
  }

  void _evaluateFace(Face face) {
    if (_isDisposed || !mounted) return;

    final rotY = face.headEulerAngleY ?? 0; // Yaw (Left/Right)
    final rotZ = face.headEulerAngleZ ?? 0; // Roll (Tilt)

    // Check Tilt (Head should be relatively vertical)
    if (rotZ.abs() > _maxTilt) {
      _resetHold("Keep head straight ⚖️");
      return;
    }

    bool isAligned = false;
    String nextInstruction = _instruction;

    // Orientation Logic based on current step
    if (_step == 0) {
      // Step 0: Look Straight
      if (rotY.abs() <= _straightYawLimit) {
        isAligned = true;
      } else {
        nextInstruction = "Look Straight 👀";
      }
    } else if (_step == 1) {
      // Step 1: Turn Left (Positive Yaw)
      if (rotY > _turnYawThreshold) {
        isAligned = true;
      } else {
        nextInstruction = "Turn Head Left ⬅️";
      }
    } else if (_step == 2) {
      // Step 2: Turn Right (Negative Yaw)
      if (rotY < -_turnYawThreshold) {
        isAligned = true;
      } else {
        nextInstruction = "Turn Head Right ➡️";
      }
    }

    // Timer Logic for capturing
    if (isAligned) {
      _holdStartTime ??= DateTime.now();

      final elapsed = DateTime.now().difference(_holdStartTime!).inSeconds;
      final remaining = _holdDurationSeconds - elapsed;

      if (remaining <= 0) {
        // Timer complete, capture photo
        if (!_isCapturing) {
          _performCapture();
        }
      } else {
        // Update UI with countdown
        if (mounted && !_isDisposed && !_isCapturing) {
          setState(() {
            _faceAligned = true;
            _secondsRemaining = remaining;
            _instruction = "Hold Still... ${remaining}s";
          });
        }
      }
    } else {
      // Reset if user moves out of alignment
      _resetHold(nextInstruction);
    }
  }

  void _resetHold(String msg) {
    // Only reset if we aren't already capturing or in the middle of submission
    if (_isCapturing || _isSubmitting) return;

    _holdStartTime = null;
    if (mounted && !_isDisposed) {
      setState(() {
        _faceAligned = false;
        _instruction = msg;
        _secondsRemaining = _holdDurationSeconds;
      });
    }
  }

  // ================= CAPTURE ACTIONS =================
  Future<void> _performCapture() async {
    if (_isCapturing || _isDisposed) return;
    setState(() {
      _isCapturing = true;
      _faceAligned = true; // Keep green circle during capture
      _instruction = "Capturing...";
    });

    _holdStartTime = null;

    try {
      if (_step == 0)
        await _captureStraight();
      else if (_step == 1)
        await _captureLeft();
      else if (_step == 2)
        await _captureRight();
    } catch (e) {
      debugPrint("Capture error: $e");
      if (mounted && !_isDisposed) {
        _showError("Capture failed, try again");
        // Reset to allow retry
        setState(() {
          _isCapturing = false;
          _holdStartTime = null;
        });
      }
    }
    // Note: _isCapturing is set to false inside specific capture methods or finally blocks
  }

  Future<void> _captureStraight() async {
    _straight = await _takePhoto();
    if (mounted && !_isDisposed) {
      setState(() {
        _step = 1;
        _progress = 0.33;
        _instruction = "Turn Left ⬅️";
        _faceAligned = false;
        _isCapturing = false;
        _secondsRemaining = _holdDurationSeconds;
      });
    }
  }

  Future<void> _captureLeft() async {
    _left = await _takePhoto();
    if (mounted && !_isDisposed) {
      setState(() {
        _step = 2;
        _progress = 0.66;
        _instruction = "Turn Right ➡️";
        _faceAligned = false;
        _isCapturing = false;
        _secondsRemaining = _holdDurationSeconds;
      });
    }
  }

  Future<void> _captureRight() async {
    _right = await _takePhoto();
    if (mounted && !_isDisposed) {
      setState(() {
        _step = 3;
        _progress = 1.0;
        _instruction = "Processing...";
        _faceAligned = false;
        _isCapturing = false;
      });

      // All 3 captured, show preview
      _showReviewDialog();
    }
  }

  Future<Uint8List> _takePhoto() async {
    // 1. Stop stream to avoid corrupted frames
    await _stopStream();

    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception("Camera not initialized");
    }

    try {
      final file = await _controller!.takePicture();
      final rawBytes = await file.readAsBytes();

      // ✅ CRITICAL FIX: force valid JPEG re-encode
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        throw Exception("Image decode failed");
      }

      // Optional resize (safe for OpenCV)
      img.Image processed = decoded;
      if (decoded.width > 640 || decoded.height > 640) {
        processed = img.copyResize(decoded, width: 640);
      }

      Uint8List jpegBytes = Uint8List.fromList(
        img.encodeJpg(processed, quality: _jpegQuality),
      );

      // Size guard (your existing logic preserved)
      if (jpegBytes.length > _maxImageSizePerImage) {
        jpegBytes = await _compressImage(jpegBytes);
      }

      // 2. Restart stream immediately
      if (!_isDisposed && mounted && _step < 3) {
        await _controller!.startImageStream(_processFrame);
      }

      return jpegBytes;
    } catch (e) {
      // Safety restart
      if (!_isDisposed && mounted) {
        await _controller!.startImageStream(_processFrame);
      }
      rethrow;
    }
  }

  Future<Uint8List> _compressImage(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      img.Image resized = image;
      if (image.width > 480 || image.height > 640) {
        resized = img.copyResize(image, width: 480, height: 640);
      }

      final compressed = img.encodeJpg(resized, quality: _jpegQuality);
      return Uint8List.fromList(compressed);
    } catch (e) {
      return imageBytes;
    }
  }

  // ================= REVIEW & SUBMIT =================
  Future<void> _showReviewDialog() async {
    await _stopStream(); // Ensure stream is stopped while reviewing

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Review Photos", textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Ensure your face is clear in all 3 photos.",
                style: TextStyle(color: Colors.grey, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildThumb(_straight, "Straight"),
                  _buildThumb(_left, "Left"),
                  _buildThumb(_right, "Right"),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _resetFlow();
            },
            icon: const Icon(Icons.refresh, color: Colors.red),
            label: const Text("Retake", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _verifyAndMark();
            },
            icon: const Icon(Icons.cloud_upload),
            label: const Text("Submit"),
          ),
        ],
      ),
    );
  }

  Widget _buildThumb(Uint8List? bytes, String label) {
    return Column(
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
            image: bytes != null
                ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover)
                : null,
          ),
          child: bytes == null
              ? const Icon(Icons.image_not_supported, color: Colors.grey)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ================= BACKEND SUBMISSION =================
  Future<void> _verifyAndMark() async {
    if (!mounted || _isDisposed) return;

    if (_straight == null || _left == null || _right == null) {
      _showError("Images not ready");
      return;
    }

    final totalSize = _straight!.length + _left!.length + _right!.length;
    if (totalSize > _totalMaxSize) {
      _showError("Images too large. Please retake.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (sessionId == null || classId == null) throw "Session info missing";

      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/verify"),
      );

      request.fields['admission_no'] = admissionNo ?? '';
      request.fields['session_id'] = sessionId ?? '';
      request.fields['student_id'] = studentId ?? '';

      final images = [_straight!, _left!, _right!];
      final names = ['face_straight.jpg', 'face_left.jpg', 'face_right.jpg'];

      for (int i = 0; i < 3; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            images[i],
            filename: names[i],
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final response = await http.Response.fromStream(
        await request.send().timeout(
          const Duration(seconds: _apiTimeoutSeconds),
        ),
      );

      if (_isDisposed || !mounted) return;

      if (response.statusCode == 200) {
        _showSuccess();
      } else if (response.statusCode == 409) {
        _showError("Attendance already marked for this session");
      } else {
        _showVerificationFailedDialog(
          "Verification failed (${response.statusCode})\nCheck backend logs.",
        );
      }
    } catch (e) {
      _showError("Error: ${e.toString()}");
    } finally {
      if (mounted && !_isDisposed) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ================= HELPERS & UI =================
  InputImage? _toInputImage(CameraImage image) {
    try {
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
    } catch (_) {
      return null;
    }
  }

  void _showError(String msg) {
    if (!mounted || _isDisposed) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
    // Do not auto reset flow here, allow user to read error or retry manually if needed
    // But for severe errors like timeout, reset might be needed.
    if (msg.contains("took too long")) {
      _resetFlow();
    } else {
      // Just restart stream if it was stopped
      if (!_controller!.value.isStreamingImages && _step < 3) {
        _controller!.startImageStream(_processFrame);
      }
    }
  }

  void _showVerificationFailedDialog(String serverMessage) {
    if (!mounted || _isDisposed) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Verification Failed"),
        content: Text(serverMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Go back to dashboard
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetFlow();
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  void _resetFlow() {
    if (!mounted || _isDisposed) return;
    _livenessTimeoutTimer?.cancel();
    _startLivenessTimeout();
    setState(() {
      _step = 0;
      _progress = 0;
      _instruction = "Look Straight 👀";
      _faceAligned = false;
      _isSubmitting = false;
      _isProcessing = false;
      _isCapturing = false;
      _straight = null;
      _left = null;
      _right = null;
      _holdStartTime = null;
      _secondsRemaining = _holdDurationSeconds;
    });
    // Restart stream
    if (_controller != null && !_controller!.value.isStreamingImages) {
      _controller!.startImageStream(_processFrame);
    }
  }

  void _showSuccess() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text("Attendance Marked!"),
        content: const Text("Verified successfully!"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
            },
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  int _getCapturedCount() {
    int count = 0;
    if (_straight != null) count++;
    if (_left != null) count++;
    if (_right != null) count++;
    return count;
  }

  Widget _buildStepIcon(int stepIndex) {
    final isCompleted = _step > stepIndex;
    final isCurrent = _step == stepIndex;
    IconData icon;
    switch (stepIndex) {
      case 0:
        icon = Icons.face;
        break;
      case 1:
        icon = Icons.arrow_back;
        break;
      case 2:
        icon = Icons.arrow_forward;
        break;
      default:
        icon = Icons.check;
    }
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? Colors.green
            : isCurrent
            ? Colors.blue
            : Colors.grey.shade300,
      ),
      child: Icon(
        isCompleted ? Icons.check : icon,
        size: 16,
        color: isCompleted || isCurrent ? Colors.white : Colors.grey.shade600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: BackButton(color: Colors.white),
        ),
        body: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Screen Camera
          CameraPreview(_controller!),

          // 2. Custom Painter for Bounding Box (Visual Feedback)
          if (_imageSize != null)
            CustomPaint(
              painter: FaceDetectorPainter(
                _faces,
                _imageSize!,
                _rotation,
                _cameraLensDirection,
                _faceAligned,
              ),
            ),

          // 3. Instruction & Progress UI
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              child: Row(
                children: [
                  _buildStepIcon(0),
                  _buildStepIcon(1),
                  _buildStepIcon(2),
                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _instruction,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _faceAligned ? Colors.green : Colors.black87,
                          ),
                        ),
                        if (_faceAligned && !_isSubmitting && !_isCapturing)
                          Text(
                            "Holding... $_secondsRemaining s",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        if (!_faceAligned && _straight != null)
                          Text(
                            "Captured: ${_getCapturedCount()}/3",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (_isSubmitting || _isCapturing)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
          ),

          // 4. Back Button
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 5. Top Progress Bar
          Positioned(
            top: 50,
            left: 70,
            right: 20,
            child: LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white24,
              color: Colors.greenAccent,
            ),
          ),
        ],
      ),
    );
  }
}

// ================= PAINTER CLASS =================
class FaceDetectorPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final bool isAligned;

  FaceDetectorPainter(
    this.faces,
    this.imageSize,
    this.rotation,
    this.cameraLensDirection,
    this.isAligned,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = isAligned ? Colors.green : Colors.red;

    for (final Face face in faces) {
      final left = translateX(
        face.boundingBox.left,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final top = translateY(
        face.boundingBox.top,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final right = translateX(
        face.boundingBox.right,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final bottom = translateY(
        face.boundingBox.bottom,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );

      // ✅ CLAMPING to ensure box stays inside screen logic (USING dart:math)
      canvas.drawRect(
        Rect.fromLTRB(
          math.max(0, left),
          math.max(0, top),
          math.min(size.width, right),
          math.min(size.height, bottom),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.faces != faces || oldDelegate.isAligned != isAligned;
  }
}

// ================= COORDINATE TRANSLATORS =================
double translateX(
  double x,
  Size canvasSize,
  Size imageSize,
  InputImageRotation rotation,
  CameraLensDirection cameraLensDirection,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return x *
          canvasSize.width /
          (Platform.isIOS ? imageSize.width : imageSize.height);
    default:
      return x * canvasSize.width / imageSize.width;
  }
}

double translateY(
  double y,
  Size canvasSize,
  Size imageSize,
  InputImageRotation rotation,
  CameraLensDirection cameraLensDirection,
) {
  switch (rotation) {
    case InputImageRotation.rotation90deg:
    case InputImageRotation.rotation270deg:
      return y *
          canvasSize.height /
          (Platform.isIOS ? imageSize.height : imageSize.width);
    default:
      return y * canvasSize.height / imageSize.height;
  }
}

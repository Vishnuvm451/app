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

  // ✅ IMAGE COMPRESSION SETTINGS
  static const int _maxImageSizePerImage = 900 * 1024; // 900KB per image max
  static const int _totalMaxSize = 3 * 1024 * 1024; // 3MB total limit
  static const int _jpegQuality = 75; // JPEG quality (0-100)

  // ✅ RELAXED THRESHOLDS (same as FaceLivenessPage)
  static const double _straightThreshold = 18.0;
  static const double _turnThreshold = 15.0;
  static const int _holdDurationSeconds = 3;
  static const int _maxLivenessSeconds = 60;

  // ================= CAMERA & ML =================
  CameraController? _controller;
  late FaceDetector _faceDetector;

  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _isSubmitting = false;
  bool _isLoadingData = true;
  bool _isDisposed = false;

  // ================= LIVENESS UI =================
  int _step = 0; // 0=Straight, 1=Left, 2=Right, 3=Done
  double _progress = 0.0;
  String _instruction = "Initializing...";
  bool _faceAligned = false;

  // Hold Timer
  DateTime? _holdStartTime;
  int _secondsRemaining = _holdDurationSeconds;
  Timer? _livenessTimeoutTimer;

  // ✅ Store ALL 3 IMAGES
  Uint8List? _straight;
  Uint8List? _left;
  Uint8List? _right;

  // ================= DATA =================
  String? studentId;
  String? studentDocId;
  String? admissionNo;
  String? classId;
  String? sessionId; // ✅ Store session ID
  String? sessionType;
  String? _errorMessage;

  // ================= LIFECYCLE =================
  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: false,
        enableTracking: true,
        minFaceSize: 0.20,
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
        if (mounted && !_isDisposed) {
          _showError("Verification took too long. Please try again.");
          _resetFlow();
        }
      },
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isProcessing = true;
    _isCapturing = true;
    _livenessTimeoutTimer?.cancel();

    _stopStream();
    _faceDetector.close();
    _controller?.dispose();
    _controller = null;

    // ✅ Clear image memory
    _straight = null;
    _left = null;
    _right = null;

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

      // ✅ Get student data
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

      // ✅ Check if face is registered
      final faceEnabled = data['face_enabled'] ?? false;
      if (faceEnabled != true) {
        throw "Face not registered. Please register first.";
      }

      // ✅ FIX: Query active session by classId and isActive = true
      QuerySnapshot sessionQuery;
      try {
        sessionQuery = await FirebaseFirestore.instance
            .collection('attendance_session')
            .where('classId', isEqualTo: classId)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get();
      } catch (e) {
        debugPrint("Session query error: $e");
        throw "Failed to check active sessions";
      }

      if (sessionQuery.docs.isEmpty) {
        throw "No active attendance session for your class";
      }

      final sessionDoc = sessionQuery.docs.first;
      sessionId = sessionDoc.id; // ✅ Store session ID
      sessionType = sessionDoc['sessionType'] ?? 'morning';

      // ✅ Initialize camera
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw "No cameras available on device";
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium, // ✅ Changed to medium for better compression
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();

      if (_isDisposed || !mounted) return;

      await _controller!.startImageStream(_processFrame);

      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _instruction = "Look Straight 👀";
        });
      }
    } catch (e) {
      debugPrint("❌ Load error: $e");
      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ================= IMAGE COMPRESSION =================
  Future<Uint8List> _compressImage(Uint8List imageBytes) async {
    try {
      // Decode image
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Resize if too large
      img.Image resized = image;
      if (image.width > 480 || image.height > 640) {
        resized = img.copyResize(
          image,
          width: 480,
          height: 640,
          interpolation: img.Interpolation.linear,
        );
      }

      // Encode with compression
      final compressed = img.encodeJpg(resized, quality: _jpegQuality);
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint("Image compression error: $e");
      return imageBytes; // Return original if compression fails
    }
  }

  double _getTotalSizeKB() {
    double total = 0;
    if (_straight != null) total += _straight!.length / 1024;
    if (_left != null) total += _left!.length / 1024;
    if (_right != null) total += _right!.length / 1024;
    return total;
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

      if (faces.isEmpty) {
        _resetHold("No face detected 🔍");
        _isProcessing = false;
        return;
      }

      _evaluateFace(faces.first);
    } catch (e) {
      debugPrint("Frame error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // ================= LIVENESS LOGIC =================
  void _evaluateFace(Face face) {
    if (_isDisposed || !mounted) return;

    final yaw = face.headEulerAngleY ?? 0;
    final roll = face.headEulerAngleZ ?? 0;

    if (roll.abs() > 25) {
      _resetHold("Keep head level ⚖️");
      return;
    }

    bool isAligned = false;
    String nextInstruction = _instruction;

    if (_step == 0) {
      if (yaw.abs() < _straightThreshold) {
        isAligned = true;
      } else {
        nextInstruction = "Look Straight 👀";
      }
    } else if (_step == 1) {
      if (yaw > _turnThreshold) {
        isAligned = true;
      } else {
        nextInstruction = "Turn Left ← (more)";
      }
    } else if (_step == 2) {
      if (yaw < -_turnThreshold) {
        isAligned = true;
      } else {
        nextInstruction = "Turn Right → (more)";
      }
    }

    if (isAligned) {
      if (_holdStartTime == null) {
        _holdStartTime = DateTime.now();
      }

      final elapsed = DateTime.now().difference(_holdStartTime!).inSeconds;
      final remaining = _holdDurationSeconds - elapsed;

      if (remaining <= 0) {
        _performCapture();
      } else {
        if (mounted && !_isDisposed) {
          setState(() {
            _faceAligned = true;
            _secondsRemaining = remaining;
            _instruction = "Hold Still... ${remaining}s ⏱️";
          });
        }
      }
    } else {
      _resetHold(nextInstruction);
    }
  }

  void _resetHold(String msg) {
    _holdStartTime = null;
    if (mounted && !_isDisposed) {
      setState(() {
        _faceAligned = false;
        _instruction = msg;
        _secondsRemaining = _holdDurationSeconds;
      });
    }
  }

  Future<void> _performCapture() async {
    if (_isCapturing || _isDisposed) return;
    _isCapturing = true;
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
      }
    } finally {
      _isCapturing = false;
    }
  }

  // ================= CAPTURE ACTIONS =================
  Future<void> _captureStraight() async {
    _straight = await _takePhoto();
    if (mounted && !_isDisposed) {
      setState(() {
        _step = 1;
        _progress = 0.33;
        _instruction = "Turn Left ←";
        _faceAligned = false;
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
        _instruction = "Turn Right →";
        _faceAligned = false;
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
        _instruction = "Verifying... 🔄";
      });
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted && !_isDisposed) {
      await _verifyAndMark();
    }
  }

  Future<Uint8List> _takePhoto() async {
    await _stopStream();
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception("Camera not initialized");
    }

    final file = await _controller!.takePicture();
    var bytes = await file.readAsBytes();

    // ✅ Compress image if needed
    if (bytes.length > _maxImageSizePerImage) {
      bytes = await _compressImage(bytes);
    }

    if (!_isDisposed && mounted && _step < 2) {
      await _controller!.startImageStream(_processFrame);
    }
    return bytes;
  }

  // ================= VERIFY & MARK =================
  Future<void> _verifyAndMark() async {
    if (!mounted || _isDisposed) return;
    if (_straight == null || _left == null || _right == null) {
      _showError("Images not ready");
      return;
    }

    // ✅ Validate total size before submission
    final totalSize = _getTotalSizeKB() * 1024;
    if (totalSize > _totalMaxSize) {
      _showError(
        "Images too large (${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB). Please retake.",
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // ✅ Verify session is still active
      if (sessionId == null || classId == null) {
        throw "Session information missing";
      }

      final sessionDoc = await FirebaseFirestore.instance
          .collection('attendance_session')
          .doc(sessionId)
          .get();

      if (!sessionDoc.exists || sessionDoc['isActive'] != true) {
        throw "Attendance session has ended";
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/verify"),
      );

      request.fields['admission_no'] = admissionNo ?? '';

      // ✅ Send ALL 3 IMAGES
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
          Duration(seconds: _apiTimeoutSeconds),
          onTimeout: () {
            throw TimeoutException("Server response timeout");
          },
        ),
      );

      if (_isDisposed || !mounted) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final statusCode = response.statusCode;

      if (statusCode == 200 && data != null && data['success'] == true) {
        // ✅ Create attendance record in Firestore
        try {
          final today = DateTime.now().toString().split(' ')[0]; // YYYY-MM-DD
          await FirebaseFirestore.instance
              .collection('attendance')
              .add({
                'studentId': studentId,
                'admissionNo': admissionNo,
                'sessionId': sessionId,
                'classId': classId,
                'status': 'present',
                'timestamp': FieldValue.serverTimestamp(),
                'confidence': (data['confidence'] ?? 0).toDouble(),
                'date': today,
              })
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw TimeoutException("Firestore write timeout");
                },
              );
        } catch (firestoreError) {
          debugPrint("Firestore write warning: $firestoreError");
          // Continue anyway - backend already marked
        }

        _showSuccess(data['confidence']?.toString() ?? "");
      } else {
        final message =
            data?['message'] ?? data?['error'] ?? 'Backend verification failed';
        _showVerificationFailedDialog(message);
      }
    } on TimeoutException catch (e) {
      _showError("Request timed out: ${e.message}. Please retry.");
    } catch (e) {
      debugPrint("❌ VERIFICATION ERROR: $e");
      _showError("Error: ${e.toString()}");
    } finally {
      if (mounted && !_isDisposed) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ================= UI HELPERS =================
  void _showError(String msg) {
    if (!mounted || _isDisposed) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
    _resetFlow();
  }

  void _showVerificationFailedDialog(String serverMessage) {
    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
        title: const Text("Verification Failed"),
        content: Text(
          serverMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) Navigator.pop(context);
              });
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _resetFlow();
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  void _resetFlow() {
    if (!mounted || _isDisposed) return;

    _isDisposed = false;
    _livenessTimeoutTimer?.cancel();
    _startLivenessTimeout();

    ScaffoldMessenger.of(context).clearSnackBars();
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
    _controller?.startImageStream(_processFrame);
  }

  void _showSuccess(String confidence) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text("Attendance Marked!"),
        content: Text(
          confidence.isNotEmpty && confidence != "0"
              ? "Verified successfully!\nConfidence: ${double.tryParse(confidence)?.toStringAsFixed(1) ?? confidence}%"
              : "Attendance marked successfully!",
          textAlign: TextAlign.center,
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
    } catch (e) {
      debugPrint("InputImage conversion error: $e");
      return null;
    }
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

  // ================= UI BUILD =================
  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text("Loading...", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 60),
                const SizedBox(height: 20),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 12,
                    ),
                  ),
                  child: const Text("Go Back"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Verify Attendance",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          Center(
            child: AspectRatio(
              aspectRatio: 1 / _controller!.value.aspectRatio,
              child: CameraPreview(_controller!),
            ),
          ),

          // Face Cutout Overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
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
                    height: 280,
                    width: 280,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Alignment Ring with Countdown
          Center(
            child: Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _faceAligned ? Colors.greenAccent : Colors.white60,
                  width: _faceAligned ? 5 : 3,
                ),
              ),
              child: _faceAligned
                  ? Center(
                      child: Text(
                        "$_secondsRemaining",
                        style: const TextStyle(
                          fontSize: 60,
                          fontWeight: FontWeight.bold,
                          color: Colors.greenAccent,
                        ),
                      ),
                    )
                  : null,
            ),
          ),

          // Progress Bar
          Positioned(
            top: 10,
            left: 20,
            right: 20,
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(10),
              color: Colors.greenAccent,
              backgroundColor: Colors.white24,
            ),
          ),

          // Instruction Card with Step Icons
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
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
                            color: _faceAligned
                                ? Colors.green.shade700
                                : Colors.black87,
                          ),
                        ),
                        if (_straight != null)
                          Text(
                            "Captured: ${_getCapturedCount()}/3 | ${_getTotalSizeKB().toStringAsFixed(1)} KB",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isSubmitting)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
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

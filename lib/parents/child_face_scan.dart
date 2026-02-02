import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;
import 'parent_dashboard.dart';

class ParentFaceScanPage extends StatefulWidget {
  final String admissionNo;
  final String studentName;

  const ParentFaceScanPage({
    super.key,
    required this.admissionNo,
    required this.studentName,
  });

  @override
  State<ParentFaceScanPage> createState() => _ParentFaceScanPageState();
}

class _ParentFaceScanPageState extends State<ParentFaceScanPage> {
  // ================= CONFIG =================
  static const String _apiBaseUrl = "https://darzo-backend-api.onrender.com";
  static const int _apiTimeoutSeconds = 45;

  static const int _maxImageSizePerImage = 900 * 1024;
  static const int _totalMaxSize = 3 * 1024 * 1024;
  static const int _jpegQuality = 75;

  // ML Kit Orientation Thresholds
  static const double _straightYawLimit = 15.0;
  static const double _turnYawThreshold = 20.0;
  static const double _maxTilt = 20.0;

  static const int _holdDurationSeconds = 3;
  static const int _maxLivenessSeconds = 60;

  // ================= CAMERA & ML =================
  CameraController? _controller;
  late FaceDetector _faceDetector;
  bool _isCameraInitialized = false;

  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _isSubmitting = false;
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

  // Images
  Uint8List? _straight;
  Uint8List? _left;
  Uint8List? _right;

  // ================= LIFECYCLE =================
  @override
  void initState() {
    super.initState();
    debugPrint("🎬 ParentFaceScan Initializing for: ${widget.admissionNo}");

    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: true,
        enableClassification: true,
        enableTracking: true,
        minFaceSize: 0.15,
      ),
    );
    _startLivenessTimeout();
    _initializeCamera();
  }

  void _startLivenessTimeout() {
    _livenessTimeoutTimer?.cancel();
    _livenessTimeoutTimer = Timer(
      const Duration(seconds: _maxLivenessSeconds),
      () {
        if (mounted && !_isDisposed && !_isSubmitting && _step < 3) {
          debugPrint("⏱️ Liveness timeout reached");
          _showError("Verification took too long. Please try again.");
          _resetFlow();
        }
      },
    );
  }

  @override
  void dispose() {
    debugPrint("🗑️ ParentFaceScan Disposing");
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
          debugPrint("✅ Image stream stopped");
        }
      } catch (e) {
        debugPrint("⚠️ Stop stream error: $e");
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint("📹 Initializing camera...");

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError("No cameras found on device");
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraLensDirection = front.lensDirection;

      _controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      if (_isDisposed || !mounted) {
        await _controller?.dispose();
        return;
      }

      _isCameraInitialized = true;

      _rotation =
          InputImageRotationValue.fromRawValue(front.sensorOrientation) ??
          InputImageRotation.rotation0deg;

      await _controller!.startImageStream(_processFrame);

      if (mounted) {
        setState(() {
          _instruction = "Look Straight 👀";
        });
      }

      debugPrint("✅ Camera initialized successfully");
    } catch (e) {
      debugPrint("❌ Camera initialization error: $e");
      if (mounted) _showError("Camera Error: $e");
    }
  }

  // ================= FRAME PROCESS =================
  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessing ||
        _isCapturing ||
        _isSubmitting ||
        _isDisposed ||
        !mounted)
      return;
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
        _isProcessing = false;
        return;
      }

      _evaluateFace(face);
    } catch (e) {
      debugPrint("❌ Frame processing error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // ================= CORE FACE MATH =================
  String? _checkFaceQuality(Face face, Size imageSize) {
    final Rect box = face.boundingBox;

    // Check Size
    if (box.width < imageSize.width * 0.15) return "Move Closer 🔍";

    // Full Face Check (Relaxed)
    if (box.left < 2 ||
        box.top < 2 ||
        box.right > imageSize.width - 2 ||
        box.bottom > imageSize.height - 2) {
      return "Keep Face Fully in Frame 🖼️";
    }
    return null;
  }

  void _evaluateFace(Face face) {
    if (_isDisposed || !mounted) return;

    final rotY = face.headEulerAngleY ?? 0;
    final rotZ = face.headEulerAngleZ ?? 0;

    if (rotZ.abs() > _maxTilt) {
      _resetHold("Keep head straight ⚖️");
      return;
    }

    bool isAligned = false;
    String nextInstruction = _instruction;

    if (_step == 0) {
      // Straight
      if (rotY.abs() <= _straightYawLimit)
        isAligned = true;
      else
        nextInstruction = "Look Straight 👀";
    } else if (_step == 1) {
      // Left
      if (rotY > _turnYawThreshold)
        isAligned = true;
      else
        nextInstruction = "Turn Head Left ⬅️";
    } else if (_step == 2) {
      // Right
      if (rotY < -_turnYawThreshold)
        isAligned = true;
      else
        nextInstruction = "Turn Head Right ➡️";
    }

    if (isAligned) {
      if (_holdStartTime == null) {
        _holdStartTime = DateTime.now();
      }

      final elapsed = DateTime.now().difference(_holdStartTime!).inSeconds;
      final remaining = _holdDurationSeconds - elapsed;

      if (remaining <= 0) {
        if (!_isCapturing) {
          _performCapture();
        }
      } else {
        if (mounted && !_isCapturing) {
          setState(() {
            _faceAligned = true;
            _secondsRemaining = remaining;
            _instruction = "Hold Still... ${remaining}s";
          });
        }
      }
    } else {
      _resetHold(nextInstruction);
    }
  }

  void _resetHold(String msg) {
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
      _faceAligned = true;
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
      debugPrint("❌ Capture error: $e");
      if (mounted) _showError("Capture failed: $e");
    }
  }

  Future<void> _captureStraight() async {
    _straight = await _takePhoto();
    if (mounted && !_isDisposed) {
      setState(() {
        _step = 1;
        _progress = 0.33;
        _instruction = "Turn Head Left ⬅️";
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
        _instruction = "Turn Head Right ➡️";
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
      await Future.delayed(const Duration(milliseconds: 500));
      if (!_isDisposed && mounted) {
        _showReviewDialog();
      }
    }
  }

  Future<Uint8List> _takePhoto() async {
    try {
      await _stopStream();
      final file = await _controller!.takePicture();
      var bytes = await file.readAsBytes();

      debugPrint("📸 Photo taken: ${bytes.length} bytes");

      if (bytes.length > _maxImageSizePerImage) {
        bytes = await _compressImage(bytes);
        debugPrint("📦 Photo compressed to: ${bytes.length} bytes");
      }

      if (!_isDisposed && mounted && _step < 3) {
        await _controller!.startImageStream(_processFrame);
      }
      return bytes;
    } catch (e) {
      debugPrint("❌ Photo capture error: $e");
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
      return Uint8List.fromList(img.encodeJpg(resized, quality: _jpegQuality));
    } catch (e) {
      debugPrint("⚠️ Image compression error: $e");
      return imageBytes;
    }
  }

  // ================= REVIEW & VERIFY =================
  Future<void> _showReviewDialog() async {
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
                "Ensure face is clear in all photos.",
                style: TextStyle(color: Colors.grey, fontSize: 13),
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
            onPressed: () {
              Navigator.pop(ctx);
              _verifyAndLinkChild();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.cloud_upload),
            label: const Text("Verify"),
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
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green, width: 2),
            color: Colors.grey[200],
            image: bytes != null
                ? DecorationImage(image: MemoryImage(bytes), fit: BoxFit.cover)
                : null,
          ),
          child: bytes == null ? const Icon(Icons.image_not_supported) : null,
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Future<void> _verifyAndLinkChild() async {
    if (_straight == null || _left == null || _right == null) {
      _showError("Missing one or more images");
      return;
    }

    // Check total size
    int totalSize =
        _straight!.lengthInBytes + _left!.lengthInBytes + _right!.lengthInBytes;
    if (totalSize > _totalMaxSize) {
      _showError("Images too large. Please retake.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      debugPrint("🔍 Fetching student data for: ${widget.admissionNo}");

      // 1. Fetch Student with error handling
      final studentDoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(widget.admissionNo)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception("Firebase timeout fetching student"),
          );

      if (!studentDoc.exists) {
        throw Exception("Student document not found");
      }

      // ✅ FIX: Removed unnecessary cast
      final studentData = studentDoc.data();

      if (studentData == null) {
        throw Exception("Student data is empty");
      }

      final studentUid = studentData['authUid'] as String?;
      if (studentUid == null || studentUid.isEmpty) {
        throw Exception("Student authUid is missing");
      }

      debugPrint("✅ Student found: $studentUid");

      // 2. Build request properly
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/verify"),
      );

      // 3. Only send admission_no (backend verified)
      request.fields['admission_no'] = widget.admissionNo;
      request.fields['session_id'] = "PARENT_LINKING";
      request.fields['student_id'] = studentUid;

      final images = [_straight!, _left!, _right!];
      final names = ['face_straight.jpg', 'face_left.jpg', 'face_right.jpg'];

      debugPrint("📤 Adding 3 images to request...");

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

      debugPrint("📡 Sending request to backend...");

      // 4. Proper timeout handling
      final response = await http.Response.fromStream(
        await request.send().timeout(
          Duration(seconds: _apiTimeoutSeconds),
          onTimeout: () => throw Exception("Backend request timeout"),
        ),
      );

      debugPrint("📥 Backend response code: ${response.statusCode}");
      // Only read substring if body is long enough
      String debugBody = response.body;
      if (debugBody.length > 200) {
        debugBody = debugBody.substring(0, 200);
      }
      debugPrint("📥 Response body: $debugBody");

      // 5. Proper JSON parsing with error handling
      late Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        throw Exception("Invalid JSON response: ${response.body}");
      }

      // 6. Check response properly
      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint("✅ Face verification successful!");

        // 7. Verify user is still logged in
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception("User not logged in");
        }

        debugPrint("💾 Updating parent profile...");

        // 8. Update with BOTH critical fields
        await FirebaseFirestore.instance
            .collection('parents')
            .doc(user.uid)
            .update({
              'linked_student_id': widget.admissionNo,
              'child_face_linked': true,
              'is_student_linked': true,
              'updated_at': FieldValue.serverTimestamp(),
            })
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw Exception("Firebase update timeout"),
            );

        debugPrint("✅ Parent profile updated successfully");

        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Verified! Confidence: ${data['confidence']?.toStringAsFixed(1) ?? 'N/A'}%",
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted && !_isDisposed) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ParentDashboard()),
            );
          }
        }
      } else {
        final error = data['error'] ?? "Unknown error";
        debugPrint("❌ Verification failed: $error");
        _showErrorDialog(
          "Face Mismatch",
          "This does not match the student's registered face.\n\nError: $error",
        );
      }
    } on FirebaseException catch (e) {
      debugPrint("❌ Firebase error: ${e.code} - ${e.message}");
      _showErrorDialog("Firebase Error", "Error: ${e.message}");
    } on SocketException catch (e) {
      debugPrint("❌ Network error: $e");
      _showErrorDialog(
        "Network Error",
        "Please check your internet connection.\n\n$e",
      );
    } on TimeoutException catch (e) {
      debugPrint("❌ Timeout error: $e");
      _showErrorDialog(
        "Request Timeout",
        "The request took too long. Please try again.",
      );
    } catch (e) {
      debugPrint("❌ Unexpected error: $e");
      _showErrorDialog("Error", e.toString());
    } finally {
      if (mounted && !_isDisposed) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showErrorDialog(String title, String msg) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
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

    debugPrint("🔄 Resetting flow...");

    _livenessTimeoutTimer?.cancel();
    _startLivenessTimeout();

    setState(() {
      _step = 0;
      _progress = 0;
      _instruction = "Look Straight 👀";
      _faceAligned = false;
      _isSubmitting = false;
      _isCapturing = false;
      _straight = null;
      _left = null;
      _right = null;
      _holdStartTime = null;
      _secondsRemaining = _holdDurationSeconds;
    });

    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.isStreamingImages) {
      _controller!.startImageStream(_processFrame);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    debugPrint("⚠️ Error: $msg");

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
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
      debugPrint("⚠️ InputImage conversion error: $e");
      return null;
    }
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                "Initializing Camera...",
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please grant camera permission",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // Face Bounding Boxes
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

          // Top Bar
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            ),
          ),

          // Progress Bar
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

          // Bottom Card
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildStepIcon(0),
                  _buildStepIcon(1),
                  _buildStepIcon(2),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _instruction,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_faceAligned && !_isSubmitting)
                          Text(
                            "Holding... $_secondsRemaining s",
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_isSubmitting)
                    const SizedBox(
                      width: 20,
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

  Widget _buildStepIcon(int index) {
    bool active = _step == index;
    bool done = _step > index;
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: done ? Colors.green : (active ? Colors.blue : Colors.grey[300]),
        shape: BoxShape.circle,
      ),
      child: Icon(
        done
            ? Icons.check
            : (index == 0
                  ? Icons.face
                  : (index == 1 ? Icons.arrow_back : Icons.arrow_forward)),
        color: (active || done) ? Colors.white : Colors.grey,
        size: 16,
      ),
    );
  }
}

// ================= PAINTER =================
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
  bool shouldRepaint(FaceDetectorPainter oldDelegate) => true;
}

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

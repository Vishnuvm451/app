import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/auth/api_warmup.dart';
import 'package:darzo/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image/image.dart' as img;

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
  // ================= CONFIG =================
  static const String _apiBaseUrl = "https://darzo-backend-api.onrender.com";
  static const int _apiTimeoutSeconds = 45;

  static const int _maxImageSizePerImage = 900 * 1024;
  static const int _totalMaxSize = 3 * 1024 * 1024; // ✅ Used in _submit
  static const int _jpegQuality = 75;

  // ML Kit Orientation Thresholds (Relaxed for easier registration)
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

  // Images
  Uint8List? _straight;
  Uint8List? _left;
  Uint8List? _right;

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
        minFaceSize: 0.15,
      ),
    );
    warmUpApiServer();
    _startLivenessTimeout();
    _initCamera();
  }

  void _startLivenessTimeout() {
    _livenessTimeoutTimer?.cancel();
    _livenessTimeoutTimer = Timer(
      const Duration(seconds: _maxLivenessSeconds),
      () {
        if (mounted && !_isDisposed && !_isSubmitting && _step < 3) {
          _showCleanError("Liveness check took too long. Please try again.");
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

  Future<bool> _onBackPressed() async {
    if (_isDisposed) return false;
    _isDisposed = true;
    _livenessTimeoutTimer?.cancel();
    await _stopStream();

    if (!mounted) return false;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
    return false;
  }

  // ================= CAMERA INIT =================
  Future<void> _initCamera() async {
    if (_isDisposed) return;

    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) _showCleanError("No cameras available");
        return;
      }

      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
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
      _isCameraInitialized = true;

      if (_isDisposed || !mounted) return;

      _rotation =
          InputImageRotationValue.fromRawValue(front.sensorOrientation) ??
          InputImageRotation.rotation0deg;

      await _controller!.startImageStream(_processFrame);

      if (mounted) {
        setState(() {
          _isLoadingData = false;
          _instruction = "Look Straight 👀";
        });
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
      if (mounted) _showCleanError("Camera initialization failed");
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
        _isProcessing = false;
        return;
      }

      _evaluateFace(face);
    } catch (e) {
      debugPrint("Frame processing error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // ================= CORE FACE MATH =================
  String? _checkFaceQuality(Face face, Size imageSize) {
    final Rect box = face.boundingBox;

    // 1. Check Size
    if (box.width < imageSize.width * 0.15) {
      return "Move Closer 🔍";
    }

    // 2. Face Position Check (Relaxed)
    // Avoid face touching edges
    if (box.left < 5 ||
        box.top < 5 ||
        box.right > imageSize.width - 5 ||
        box.bottom > imageSize.height - 5) {
      return "Keep Face Fully in Frame 🖼️";
    }

    return null;
  }

  void _evaluateFace(Face face) {
    if (_isDisposed || !mounted) return;

    final rotY = face.headEulerAngleY ?? 0;
    final rotZ = face.headEulerAngleZ ?? 0;

    // Check Tilt
    if (rotZ.abs() > _maxTilt) {
      _resetHold("Keep head straight ⚖️");
      return;
    }

    bool isAligned = false;
    String nextInstruction = _instruction;

    if (_step == 0) {
      // Straight
      if (rotY.abs() <= _straightYawLimit) {
        isAligned = true;
      } else {
        nextInstruction = "Look Straight 👀";
      }
    } else if (_step == 1) {
      // Left
      if (rotY > _turnYawThreshold) {
        isAligned = true;
      } else {
        nextInstruction = "Turn Head Left ⬅️";
      }
    } else if (_step == 2) {
      // Right
      if (rotY < -_turnYawThreshold) {
        isAligned = true;
      } else {
        nextInstruction = "Turn Head Right ➡️";
      }
    }

    // Timer Logic
    if (isAligned) {
      if (_holdStartTime == null) {
        _holdStartTime = DateTime.now();
      }

      final elapsed = DateTime.now().difference(_holdStartTime!).inSeconds;
      final remaining = _holdDurationSeconds - elapsed;

      if (remaining <= 0) {
        if (!_isCapturing) _performCapture();
      } else {
        if (mounted && !_isDisposed && !_isCapturing) {
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
      debugPrint("Capture error: $e");
      if (mounted && !_isDisposed) {
        _showCleanError("Capture failed, try again");
        setState(() => _isCapturing = false);
      }
    }
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
      _showReviewDialog();
    }
  }

  Future<Uint8List> _takePhoto() async {
    await _stopStream();
    if (_controller == null || !_controller!.value.isInitialized) {
      throw Exception("Camera not initialized");
    }

    final file = await _controller!.takePicture();
    var bytes = await file.readAsBytes();

    if (bytes.length > _maxImageSizePerImage) {
      bytes = await _compressImage(bytes);
    }

    if (!_isDisposed && mounted && _step < 3) {
      await _controller!.startImageStream(_processFrame);
    }
    return bytes;
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

  // ================= REVIEW DIALOG =================
  Future<void> _showReviewDialog() async {
    await _stopStream();
    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Review Photos", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Ensure your face is clear in all 3 photos.",
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
              _submit();
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
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green, width: 2),
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
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ================= BACKEND SUBMISSION =================
  Future<void> _submit() async {
    if (!mounted || _isDisposed) return;
    if (_straight == null || _left == null || _right == null) {
      _showCleanError("Images not ready");
      return;
    }

    int totalSize =
        _straight!.lengthInBytes + _left!.lengthInBytes + _right!.lengthInBytes;
    if (totalSize > _totalMaxSize) {
      _showCleanError(
        "Images too large (${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB). Retrying...",
      );
      _resetFlow();
      return;
    }

    setState(() => _isSubmitting = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showCleanError("Session expired. Please login again.");
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/register"),
      );
      req.fields['admission_no'] = widget.admissionNo;
      req.fields['auth_uid'] = user.uid;

      final images = [_straight!, _left!, _right!];
      final names = ['face_straight.jpg', 'face_left.jpg', 'face_right.jpg'];

      for (int i = 0; i < 3; i++) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'images',
            images[i],
            filename: names[i],
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final response = await http.Response.fromStream(
        await req.send().timeout(const Duration(seconds: _apiTimeoutSeconds)),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await FirebaseFirestore.instance
            .collection('student')
            .doc(widget.admissionNo)
            .update({'face_enabled': true});

        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text("Face Registered Successfully!"),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
          _onBackPressed();
        }
      } else {
        _showVerificationFailedDialog(data['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _showCleanError("Connection failed. Check your internet.");
    } finally {
      if (mounted && !_isDisposed) {
        setState(() => _isSubmitting = false);
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
        content: Text(serverMessage, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onBackPressed();
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetFlow();
            },
            child: const Text("Recapture"),
          ),
        ],
      ),
    );
  }

  void _showCleanError(String msg) {
    if (!mounted || _isDisposed) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        action: SnackBarAction(
          label: "RETRY",
          textColor: Colors.white,
          onPressed: _resetFlow,
        ),
      ),
    );
  }

  void _resetFlow() {
    if (!mounted) return;
    _isDisposed = false;
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

    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Camera Preview
            CameraPreview(_controller!),

            // 2. Face Painter (Green/Red Box)
            CustomPaint(
              painter: FaceDetectorPainter(
                _faces,
                _imageSize!,
                _rotation,
                _cameraLensDirection,
                _faceAligned,
              ),
            ),

            // 3. Bottom Card UI
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
                              color: _faceAligned
                                  ? Colors.green.shade700
                                  : Colors.black87,
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
                              "Captured: ${_straight != null ? 1 : 0}/3",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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
                onPressed: _onBackPressed,
              ),
            ),

            // 5. Progress Bar
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

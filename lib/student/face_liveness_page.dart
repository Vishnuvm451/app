import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
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
  // ✅ API Configuration
  static const String _apiBaseUrl = "https://darzo-backend-api.onrender.com";

  // ✅ RELAXED THRESHOLDS
  static const double _straightThreshold = 18.0;
  static const double _turnThreshold = 15.0;

  // ✅ IMAGE COMPRESSION SETTINGS
  static const int _maxImageSizePerImage = 900 * 1024; // 900KB per image max
  static const int _totalMaxSize = 3 * 1024 * 1024; // 3MB total limit
  static const int _jpegQuality = 75; // JPEG quality (0-100)

  CameraController? _controller;
  bool _isProcessing = false;
  bool _isCapturing = false;
  bool _isSubmitting = false;
  bool _isDisposed = false;

  int _step = 0; // 0=Straight, 1=Left, 2=Right, 3=Done
  double _progress = 0.0;
  String _instruction = "Initializing...";

  // Hold Timer Variables
  DateTime? _holdStartTime;
  static const int _holdDurationSeconds = 3;
  int _secondsRemaining = 3;

  bool _faceAligned = false;

  Uint8List? _straight;
  Uint8List? _left;
  Uint8List? _right;

  late FaceDetector _faceDetector;

  // ✅ Timeout for liveness check
  Timer? _livenessTimeoutTimer;
  static const int _maxLivenessSeconds = 60;

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
    warmUpApiServer();
    _initCamera();
  }

  void _startLivenessTimeout() {
    _livenessTimeoutTimer?.cancel();
    _livenessTimeoutTimer = Timer(
      const Duration(seconds: _maxLivenessSeconds),
      () {
        if (mounted && !_isDisposed) {
          _showCleanError("Liveness check took too long. Please try again.");
          _reset();
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

  Future<bool> _onBackPressed() async {
    if (_isDisposed) return false;

    _isProcessing = true;
    _isCapturing = true;
    _isSubmitting = true;
    _isDisposed = true;
    _livenessTimeoutTimer?.cancel();

    if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    await _stopStream();

    try {
      await _faceDetector.close();
    } catch (_) {}

    try {
      await _controller?.dispose();
      _controller = null;
    } catch (_) {}

    // ✅ Clear memory
    _straight = null;
    _left = null;
    _right = null;

    if (!mounted) return false;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
    return false;
  }

  // ================= CAMERA =================
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

      _controller = CameraController(
        front,
        // ✅ Medium resolution optimized for backend
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();

      if (_isDisposed || !mounted) return;

      await _controller!.startImageStream(_processFrame);

      if (mounted) {
        setState(() => _instruction = "Look Straight 👀");
      }
    } catch (e) {
      debugPrint("Camera init error: $e");
      if (mounted) _showCleanError("Camera initialization failed");
    }
  }

  Future<void> _stopStream() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      if (_controller!.value.isStreamingImages) {
        await _controller!.stopImageStream();
      }
    } catch (e) {
      debugPrint("Stop stream error: $e");
    }
  }

  // ================= FRAME PROCESS =================
  Future<void> _processFrame(CameraImage image) async {
    // ✅ Stricter processing guards
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

      // ✅ Re-check disposed state before setState
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
      debugPrint("Frame processing error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // ================= LIVENESS LOGIC =================
  void _evaluateFace(Face face) {
    if (_isDisposed || !mounted) return;

    final yaw = face.headEulerAngleY ?? 0;
    final roll = face.headEulerAngleZ ?? 0;

    // Basic Geometry Check
    if (roll.abs() > 25) {
      _resetHold("Keep head level ⚖️");
      return;
    }

    bool isAligned = false;
    String nextInstruction = _instruction;

    if (_step == 0) {
      // STRAIGHT
      if (yaw.abs() < _straightThreshold) {
        isAligned = true;
      } else {
        nextInstruction = "Look Straight 👀";
      }
    } else if (_step == 1) {
      // LEFT
      if (yaw > _turnThreshold) {
        isAligned = true;
      } else {
        nextInstruction = "Turn Left ← (more)";
      }
    } else if (_step == 2) {
      // RIGHT
      if (yaw < -_turnThreshold) {
        isAligned = true;
      } else {
        nextInstruction = "Turn Right → (more)";
      }
    }

    // Handle Hold Timer
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
      if (_step == 0) {
        await _captureStraight();
      } else if (_step == 1) {
        await _captureLeft();
      } else if (_step == 2) {
        await _captureRight();
      }
    } catch (e) {
      debugPrint("Capture error: $e");
      if (mounted && !_isDisposed) {
        _showCleanError("Capture failed, try again");
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
        _instruction = "All photos captured! ✓";
      });
    }
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted && !_isDisposed) {
      await _showReviewDialog();
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

    if (!_isDisposed && mounted) {
      await _controller!.startImageStream(_processFrame);
    }
    return bytes;
  }

  // ✅ Image compression utility
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

  // ================= REVIEW DIALOG =================
  Future<void> _showReviewDialog() async {
    await _stopStream();
    if (!mounted || _isDisposed) return;

    await showDialog(
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
              textAlign: TextAlign.center,
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
            // ✅ Show total file size
            if (_straight != null && _left != null && _right != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  "Total size: ${_getTotalSizeKB().toStringAsFixed(1)} KB",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _reset();
            },
            icon: const Icon(Icons.refresh, color: Colors.red),
            label: const Text("Retake", style: TextStyle(color: Colors.red)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

  double _getTotalSizeKB() {
    double total = 0;
    if (_straight != null) total += _straight!.length / 1024;
    if (_left != null) total += _left!.length / 1024;
    if (_right != null) total += _right!.length / 1024;
    return total;
  }

  Widget _buildThumb(Uint8List? bytes, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
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

    // ✅ Validate total size before submission
    final totalSize = _getTotalSizeKB() * 1024;
    if (totalSize > _totalMaxSize) {
      _showCleanError(
        "Images too large (${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB). Please retake.",
      );
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

      // ✅ Add timeout to request
      final streamedResponse = await req.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException("Backend request timed out");
        },
      );

      final res = await http.Response.fromStream(streamedResponse);
      final statusCode = res.statusCode;

      if (_isDisposed || !mounted) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>?;

      if (statusCode == 200 && data != null && data['success'] == true) {
        // ✅ Update Firestore with error handling
        try {
          await FirebaseFirestore.instance
              .collection('student')
              .doc(widget.admissionNo)
              .update({'face_enabled': true})
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw TimeoutException("Firestore update timed out");
                },
              );
        } catch (firestoreError) {
          debugPrint("Firestore update warning: $firestoreError");
          // Continue anyway - backend registered the face
        }

        if (mounted && !_isDisposed) {
          ScaffoldMessenger.of(context).clearSnackBars();
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
          await _onBackPressed();
        }
      } else {
        final message = data?['message'] ?? 'Backend verification failed';
        _showVerificationFailedDialog(message);
      }
    } on TimeoutException catch (e) {
      _showCleanError("Request timed out: ${e.message}. Please retry.");
    } catch (e) {
      debugPrint("Submission error: $e");
      _showCleanError("Connection failed. Check your internet and retry.");
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
              _onBackPressed();
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
              _reset();
            },
            icon: const Icon(Icons.camera_alt),
            label: const Text("Recapture"),
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
        action: SnackBarAction(
          label: "RETRY",
          textColor: Colors.white,
          onPressed: _reset,
        ),
      ),
    );
  }

  void _reset() {
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
    _initCamera();
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

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                "Starting Camera...",
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _onBackPressed();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _onBackPressed,
          ),
          title: const Text(
            "Face Registration",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),
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
                              "Captured: ${_getCapturedCount()}/3",
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
}

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

/// ======================================================
/// FACE DETECTION VIEW
/// ======================================================
class FaceDetectionView extends StatefulWidget {
  final Function(List<Uint8List>) onCaptureComplete;
  final bool singleImageMode;

  const FaceDetectionView({
    super.key,
    required this.onCaptureComplete,
    this.singleImageMode = false,
  });

  @override
  State<FaceDetectionView> createState() => FaceDetectionViewState();
}

class FaceDetectionViewState extends State<FaceDetectionView> {
  CameraController? _controller;
  late FaceDetector _faceDetector;

  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _isCapturing = false;

  /// Master switches
  bool _isCompleted = false;
  bool _isDisposed = false;

  /// State
  int _step = 0; // 0: Straight, 1: Turn Left, 2: Turn Right
  String _instruction = "Initializing...";
  bool _isAligned = false;
  double _currentQualityScore = 0.0;

  List<Face> _faces = [];
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  CameraLensDirection _cameraLensDirection = CameraLensDirection.front;

  // Captured Images
  Uint8List? _straight;
  Uint8List? _left;
  Uint8List? _right;

  Timer? _countdownTimer;
  int _countdownValue = 3;

  @override
  void initState() {
    super.initState();

    // 1. Setup ML Kit with Contour & Landmarks enabled
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableLandmarks: true, // Needed for Euler Y logic
        enableContours: true, // Needed for 133 point mapping
        enableClassification: true, // For eyes/smile check
        enableTracking: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );

    _initializeCamera();
  }

  /// ------------------------------------------------------
  /// CAMERA SETUP
  /// ------------------------------------------------------
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraLensDirection = frontCamera.lensDirection;

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      _rotation =
          InputImageRotationValue.fromRawValue(frontCamera.sensorOrientation) ??
          InputImageRotation.rotation0deg;

      if (mounted && !_isDisposed) {
        setState(() => _isCameraInitialized = true);
        _startStream();
      }
    } catch (e) {
      debugPrint("❌ Camera init error: $e");
    }
  }

  Future<void> _startStream() async {
    if (_isCompleted || _isDisposed || !mounted) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (!_controller!.value.isStreamingImages) {
      await _controller!.startImageStream(_processCameraImage);
      if (mounted) {
        setState(() => _instruction = "Look Straight 👀");
      }
    }
  }

  /// ------------------------------------------------------
  /// PROCESSING LOOP
  /// ------------------------------------------------------
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDisposed ||
        _isProcessing ||
        _isCapturing ||
        _isCompleted ||
        !mounted)
      return;

    _isProcessing = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector.processImage(inputImage);

      if (_isDisposed || _isCompleted || !mounted) return;

      setState(() {
        _faces = faces;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });

      _evaluateFaces(faces);
    } catch (e) {
      if (!_isDisposed) debugPrint("❌ Processing error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  /// ------------------------------------------------------
  /// QUALITY & ALIGNMENT LOGIC
  /// ------------------------------------------------------
  void _evaluateFaces(List<Face> faces) {
    if (_isDisposed || _isCompleted) return;

    if (faces.isEmpty) {
      _resetState("No Face Detected 🔍");
      return;
    }

    final face = faces.first;

    // 1. Calculate Score based on Contours and Landmarks
    final score = FaceQualityUtils.calculateFaceQuality(
      face,
      _imageSize!,
      _step,
    );
    final rotY = face.headEulerAngleY ?? 0;

    // 2. Determine Alignment based on Steps
    bool alignmentSuccess = false;
    String instruction = FaceQualityUtils.getStatusText(score, face, _step);

    // Thresholds
    final minScore = _step == 0 ? 80.0 : 40.0; // Stricter for straight face

    if (score >= minScore) {
      if (_step == 0) {
        // Straight: -12 to 12 degrees
        // Must detect frontal landmarks (Eyes, Nose, Mouth)
        if (rotY.abs() <= 12 &&
            FaceQualityUtils.areFrontalLandmarksVisible(face)) {
          alignmentSuccess = true;
        } else {
          instruction = "Look Directly at Camera";
        }
      } else if (_step == 1) {
        // Turn Left: +18 → +90
        if (rotY >= 18 && rotY <= 90) alignmentSuccess = true;
      } else if (_step == 2) {
        // Turn Right: -18 → -90
        if (rotY <= -18 && rotY >= -90) alignmentSuccess = true;
      }
    }

    if (alignmentSuccess) {
      _startCountdown();
    } else {
      _resetCountdown();
    }

    _updateUI(alignmentSuccess, instruction, score);
  }

  void _updateUI(bool aligned, String text, double score) {
    if (_isDisposed || _isCompleted || !mounted) return;
    setState(() {
      _isAligned = aligned;
      _instruction = aligned ? "Hold Still... $_countdownValue" : text;
      _currentQualityScore = score;
    });
  }

  /// ------------------------------------------------------
  /// CAPTURE LOGIC
  /// ------------------------------------------------------
  void _startCountdown() {
    if (_countdownTimer != null) return;
    if (!_isAligned || _isCapturing || _isCompleted) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || _isCompleted || !mounted) {
        timer.cancel();
        return;
      }
      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
      } else {
        _resetCountdown();
        _captureImage();
      }
    });
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted) setState(() => _countdownValue = 3);
  }

  void _resetState(String msg) {
    _resetCountdown();
    if (mounted) {
      setState(() {
        _isAligned = false;
        _instruction = msg;
        _currentQualityScore = 0.0;
      });
    }
  }

  Future<void> _captureImage() async {
    if (_isCapturing) return;
    _isCapturing = true;
    await HapticFeedback.mediumImpact();

    try {
      await _controller!.stopImageStream();
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();
      final compressed = await _compressImage(bytes);

      if (_step == 0) _straight = compressed;
      if (_step == 1) _left = compressed;
      if (_step == 2) _right = compressed;

      await HapticFeedback.selectionClick();

      if (widget.singleImageMode) {
        _isCompleted = true;
        widget.onCaptureComplete([_straight!]);
        return;
      }

      if (_step < 2) {
        await Future.delayed(const Duration(seconds: 2)); // 👈 REQUIRED GAP

        setState(() {
          _step++;
          _isCapturing = false;
          _isAligned = false;
          _countdownValue = 3;
          _instruction = _step == 1 ? "Turn Left Slowly" : "Turn Right Slowly";
        });

        _startStream();
      } else {
        _isCompleted = true;
        widget.onCaptureComplete([_straight!, _left!, _right!]);
      }
    } catch (e) {
      debugPrint("❌ Capture failed: $e");
      _isCapturing = false;
      _resetCountdown();
      await Future.delayed(const Duration(milliseconds: 400));
      _startStream();
    }
  }

  Future<Uint8List> _compressImage(Uint8List raw) async {
    // Run in isolate or async compute in production
    final image = img.decodeImage(raw);
    if (image == null) return raw;
    final resized = img.copyResize(image, width: 640);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: _rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// 🔄 Public reset method (Accessed via GlobalKey)
  void resetFlow() {
    if (_isDisposed || !mounted) return;

    // 1. Stop any active countdown
    _countdownTimer?.cancel();
    _countdownTimer = null;

    // 2. Reset all state to Step 0
    setState(() {
      _isCompleted = false;
      _isProcessing = false;
      _isCapturing = false;

      _step = 0;
      _countdownValue = 3;

      _instruction = "Look Straight 👀";
      _isAligned = false;
      _currentQualityScore = 0.0;

      // Clear captured images
      _straight = null;
      _left = null;
      _right = null;

      _faces = [];
    });

    // 3. Restart the camera stream if it was stopped
    _startStream();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _countdownTimer?.cancel();
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized)
      return const Center(child: CircularProgressIndicator());

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),

        // Custom Painter for Contours and Landmarks
        if (_imageSize != null)
          CustomPaint(
            painter: FacePainter(
              faces: _faces,
              imageSize: _imageSize!,
              cameraLensDirection: _cameraLensDirection,
              isAligned: _isAligned,
              currentStep: _step,
            ),
          ),

        // UI Overlays
        Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Quality: ${_currentQualityScore.toInt()}%",
                  style: TextStyle(
                    color: FaceQualityUtils.getScoreColor(_currentQualityScore),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        Positioned(
          bottom: 40,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black87.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _instruction,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isAligned ? Colors.greenAccent : Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ======================================================
/// FACE UTILS: LOGIC & SCORING
/// ======================================================
class FaceQualityUtils {
  // Checks if critical landmarks are present for Straight face
  // Euler Y range: -12 to 12
  static bool areFrontalLandmarksVisible(Face face) {
    final Map<FaceLandmarkType, FaceLandmark?> l = face.landmarks;
    return l[FaceLandmarkType.leftEye] != null &&
        l[FaceLandmarkType.rightEye] != null &&
        l[FaceLandmarkType.noseBase] != null &&
        l[FaceLandmarkType.bottomMouth] != null;
  }

  static double calculateFaceQuality(Face face, Size imageSize, int step) {
    double score = 100.0;

    // 1. Face Size Check
    final width = face.boundingBox.width;
    final minWidth = imageSize.width * 0.25; // Face must be 25% of screen width
    if (width < minWidth) score -= 40;

    // 2. Geometry Checks (Euler Angles)
    final rotY = (face.headEulerAngleY ?? 0).abs();
    final rotZ = (face.headEulerAngleZ ?? 0).abs();

    // For straight face, penalize rotation
    if (step == 0) {
      if (rotY > 12) score -= (rotY - 12) * 3; // Penalize looking away
      if (rotZ > 10) score -= (rotZ - 10) * 3; // Penalize head tilt
    }

    // 3. Centering Check
    final centerX = face.boundingBox.center.dx;
    final imgCenterX =
        imageSize.width / 2; // Note: Android rotates size usually
    // Simple centering logic could be added here

    return score.clamp(0.0, 100.0);
  }

  static Color getScoreColor(double score) {
    if (score >= 80) return Colors.greenAccent;
    if (score >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  static String getStatusText(double score, Face face, int step) {
    if (score >= 80) {
      if (step == 0) return "Perfect! Hold Still";
      if (step == 1) return "Turn Left Now";
      if (step == 2) return "Turn Right Now";
    }

    // Feedback based on specific issues
    if (face.boundingBox.width < 100) return "Move Closer";

    final rotZ = (face.headEulerAngleZ ?? 0);
    if (rotZ.abs() > 10) return "Keep Head Level";

    if (step == 0) {
      final rotY = face.headEulerAngleY ?? 0;
      if (rotY.abs() > 12) return "Look Straight";
    }

    return "Align Face in Center";
  }
}

/// ======================================================
/// FACE PAINTER: CONTOURS & LANDMARKS
/// ======================================================
class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;
  final bool isAligned;
  final int currentStep;

  FacePainter({
    required this.faces,
    required this.imageSize,
    required this.cameraLensDirection,
    required this.isAligned,
    required this.currentStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = isAligned ? Colors.greenAccent : Colors.redAccent;

    final landmarkPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.yellowAccent;

    final contourPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.cyanAccent.withOpacity(0.6);

    for (final face in faces) {
      // 1. Draw Bounding Box
      final rect = _scaleRect(
        rect: face.boundingBox,
        imageSize: imageSize,
        widgetSize: size,
        lensDirection: cameraLensDirection,
      );
      canvas.drawRect(rect, boxPaint);

      if (currentStep == 0) {
        // A. Draw Contours (133 Points logic)
        void drawContour(FaceContourType type) {
          final contour = face.contours[type];
          if (contour?.points != null) {
            final path = Path();
            // Map points to screen coordinates
            final points = contour!.points
                .map(
                  (p) => _scalePoint(
                    point: p,
                    imageSize: imageSize,
                    widgetSize: size,
                    lensDirection: cameraLensDirection,
                  ),
                )
                .toList();

            if (points.isNotEmpty) {
              path.moveTo(points.first.dx, points.first.dy);
              for (var i = 1; i < points.length; i++) {
                path.lineTo(points[i].dx, points[i].dy);
              }
              // Close face oval
              if (type == FaceContourType.face) path.close();
              canvas.drawPath(path, contourPaint);
            }
          }
        }

        // Draw all key contours
        drawContour(FaceContourType.face);
        drawContour(FaceContourType.leftEyebrowTop);
        drawContour(FaceContourType.leftEyebrowBottom);
        drawContour(FaceContourType.rightEyebrowTop);
        drawContour(FaceContourType.rightEyebrowBottom);
        drawContour(FaceContourType.leftEye);
        drawContour(FaceContourType.rightEye);
        drawContour(FaceContourType.upperLipTop);
        drawContour(FaceContourType.upperLipBottom);
        drawContour(FaceContourType.lowerLipTop);
        drawContour(FaceContourType.lowerLipBottom);
        drawContour(FaceContourType.noseBridge);
        drawContour(FaceContourType.noseBottom);

        // B. Draw Landmarks (Dots)
        for (final landmark in face.landmarks.values) {
          if (landmark != null) {
            final point = _scalePoint(
              point: landmark.position,
              imageSize: imageSize,
              widgetSize: size,
              lensDirection: cameraLensDirection,
            );
            canvas.drawCircle(point, 3, landmarkPaint);
          }
        }
      }
    }
  }

  // --- Scaling Helpers ---

  Rect _scaleRect({
    required Rect rect,
    required Size imageSize,
    required Size widgetSize,
    required CameraLensDirection lensDirection,
  }) {
    final double scaleX =
        widgetSize.width /
        (Platform.isAndroid ? imageSize.height : imageSize.width);
    final double scaleY =
        widgetSize.height /
        (Platform.isAndroid ? imageSize.width : imageSize.height);

    double left = rect.left * scaleX;
    double right = rect.right * scaleX;

    // Mirroring for Front Camera
    if (lensDirection == CameraLensDirection.front) {
      left = widgetSize.width - rect.right * scaleX;
      right = widgetSize.width - rect.left * scaleX;
    }

    return Rect.fromLTRB(left, rect.top * scaleY, right, rect.bottom * scaleY);
  }

  Offset _scalePoint({
    required Point<int> point,
    required Size imageSize,
    required Size widgetSize,
    required CameraLensDirection lensDirection,
  }) {
    final double scaleX =
        widgetSize.width /
        (Platform.isAndroid ? imageSize.height : imageSize.width);
    final double scaleY =
        widgetSize.height /
        (Platform.isAndroid ? imageSize.width : imageSize.height);

    double x = point.x * scaleX;
    if (lensDirection == CameraLensDirection.front) {
      x = widgetSize.width - x;
    }
    return Offset(x, point.y * scaleY);
  }

  @override
  bool shouldRepaint(covariant FacePainter oldDelegate) =>
      oldDelegate.faces != faces ||
      oldDelegate.isAligned != isAligned ||
      oldDelegate.currentStep != currentStep;
}

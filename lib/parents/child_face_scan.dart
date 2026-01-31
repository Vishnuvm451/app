import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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
  static const String _apiBaseUrl = "https://darzo-backend-api.onrender.com";

  CameraController? _controller;
  late FaceDetector _faceDetector;
  bool _isProcessingFrame = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
    );
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _controller!.initialize();
    if (mounted) {
      setState(() {});
      _controller!.startImageStream(_processFrame);
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_isProcessingFrame || _isVerifying) return;
    _isProcessingFrame = true;

    try {
      final input = _toInputImage(image);
      if (input == null) return;

      final faces = await _faceDetector.processImage(input);
      if (faces.isNotEmpty) {
        // Face Detected! Capture and Verify
        await _controller!.stopImageStream();
        await _captureAndVerify();
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  Future<void> _captureAndVerify() async {
    setState(() => _isVerifying = true);

    try {
      final file = await _controller!.takePicture();
      final bytes = await file.readAsBytes();

      // Send to Backend
      final req = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/verify"),
      );
      req.fields['admission_no'] = widget.admissionNo;
      req.fields['session_id'] = "PARENT_LINKING";

      // Fetch uid for verification
      final studentDoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(widget.admissionNo)
          .get();
      req.fields['student_id'] = studentDoc['authUid'];

      // Send same image 3 times to satisfy backend requirement
      for (int i = 0; i < 3; i++) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: 'face.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      final res = await req.send();
      final respStr = await res.stream.bytesToString();
      final data = jsonDecode(respStr);

      if (res.statusCode == 200 && data['success'] == true) {
        // ✅ SUCCESS: Link Parent to Student
        final parentUid = FirebaseAuth.instance.currentUser!.uid;

        // Update parents collection
        await FirebaseFirestore.instance
            .collection('parents')
            .doc(parentUid)
            .update({'linked_student_id': widget.admissionNo});

        if (mounted) {
          _showCleanSnackBar("Face verified! Connecting...", isError: false);

          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ParentDashboard()),
              );
            }
          });
        }
      } else {
        _showCleanSnackBar("Face Mismatch! Not your child.", isError: true);
        _resetCamera();
      }
    } catch (e) {
      _showCleanSnackBar("Connection Error: ${e.toString()}", isError: true);
      _resetCamera();
    }
  }

  void _resetCamera() {
    if (mounted) {
      setState(() => _isVerifying = false);
      _controller!.startImageStream(_processFrame);
    }
  }

  void _showCleanSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  InputImage? _toInputImage(CameraImage image) {
    try {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation270deg,
          format: InputImageFormat.nv21,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            Center(child: CameraPreview(_controller!)),

          // Overlay
          Container(decoration: const BoxDecoration(color: Colors.transparent)),

          // Face Guide
          Center(
            child: Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Top Bar
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Instruction Text
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "Verifying for: ${widget.studentName}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Align Child's Face",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 4,
                        color: Colors.black54,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (_isVerifying)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF2196F3),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "Verifying...",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/login.dart';
import 'package:flutter/material.dart';

class FaceCapturePage extends StatefulWidget {
  final String studentUid;
  final String studentName;

  const FaceCapturePage({
    super.key,
    required this.studentUid,
    required this.studentName,
  });

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();
    if (mounted) setState(() => _isCameraInitialized = true);
  }

  Future<void> _captureAndUpload() async {
    if (_isCapturing || !_isCameraInitialized) return;

    setState(() => _isCapturing = true);

    try {
      // 🔥 REAL CAPTURE (UNCOMMENT LATER)
      // final image = await _cameraController!.takePicture();
      // await uploadFaceImage(widget.studentUid, File(image.path));

      // ✅ MANDATORY FIRESTORE UPDATE
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentUid)
          .update({
            'face_enabled': true,
            'face_registered_at': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Face registered successfully")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Face capture failed: $e")));
    } finally {
      setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        title: const Text("Face Registration"),
        backgroundColor: const Color(0xFF2196F3),
        automaticallyImplyLeading: false, // 🚫 BACK DISABLED
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            "Welcome, ${widget.studentName}",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            "Face registration is mandatory",
            style: TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Container(
            height: 280,
            width: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
            ),
            clipBehavior: Clip.hardEdge,
            child: _isCameraInitialized
                ? CameraPreview(_cameraController!)
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _captureAndUpload,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                child: _isCapturing
                    ? const CircularProgressIndicator()
                    : const Text(
                        "CAPTURE FACE",
                        style: TextStyle(
                          color: Color(0xFF2196F3),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

import 'package:camera/camera.dart';
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
  // ---------------- CAMERA STATE ----------------
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // ---------------- INIT CAMERA ----------------
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      // Use front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  // ---------------- CAPTURE LOGIC (Backend Hook) ----------------
  Future<void> _captureAndUpload() async {
    if (!_isCameraInitialized || _isCapturing) return;

    setState(() => _isCapturing = true);

    try {
      // 1. Capture Image
      // final image = await _cameraController!.takePicture();

      // 2. BACKEND HOOK: Upload 'image.path' to Firebase Storage
      // await uploadFaceImage(widget.studentUid, File(image.path));

      // 3. BACKEND HOOK: Update Firestore 'face_enabled: true'
      // await FirebaseFirestore.instance.collection('students').doc(widget.studentUid).update({'face_enabled': true});

      // Simulation delay
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Face Registered Successfully!")),
        );
        // Navigate to Login after success
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
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
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            "Welcome, ${widget.studentName}",
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "Please position your face in the circle",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const Spacer(),
          // CAMERA PREVIEW CIRCLE
          Container(
            height: 300,
            width: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              color: Colors.black12,
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
            padding: const EdgeInsets.all(30.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _captureAndUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
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
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text(
              "Skip for now",
              style: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

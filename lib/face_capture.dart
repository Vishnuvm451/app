import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  bool _isLightingGood = true;
  String? _error;

  // 🔧 UPDATE WITH YOUR IP
  static const String _apiBaseUrl = "http://YOUR_IP:8000";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // ===================================================
  // INITIALIZE CAMERA
  // ===================================================
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.setExposureMode(ExposureMode.auto);

      if (!mounted) return;

      setState(() => _isCameraInitialized = true);

      _checkLighting();
    } catch (e) {
      setState(() => _error = "Camera initialization failed");
    }
  }

  // ===================================================
  // SIMPLE LIGHTING CHECK (SAFE & STABLE)
  // ===================================================
  Future<void> _checkLighting() async {
    try {
      final step = await _cameraController!.getExposureOffsetStepSize();

      // Heuristic:
      // Very low exposure step usually means dark environment
      setState(() {
        _isLightingGood = step > 0.01;
      });
    } catch (_) {
      setState(() {
        _isLightingGood = true; // fallback safe
      });
    }
  }

  // ===================================================
  // CAPTURE + BACKEND + FIRESTORE + LOGOUT
  // ===================================================
  Future<void> _captureAndRegisterFace() async {
    if (_isCapturing || !_isCameraInitialized) return;

    if (!_isLightingGood) {
      setState(() {
        _error = "Lighting is too low. Move to a brighter place.";
      });
      return;
    }

    setState(() {
      _isCapturing = true;
      _error = null;
    });

    try {
      final image = await _cameraController!.takePicture();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/register-face"),
      );

      request.fields['student_uid'] = widget.studentUid;
      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final response = await request.send();

      if (response.statusCode != 200) {
        throw "Face registration failed";
      }

      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentUid)
          .update({
            'face_enabled': true,
            'face_registered_at': FieldValue.serverTimestamp(),
          });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Face registered successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // ===================================================
  // UI
  // ===================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        title: const Text("Face Registration"),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2196F3),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          Text(
            "Welcome, ${widget.studentName}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),
          const Text(
            "Align your face inside the circle",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),

          if (!_isLightingGood)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                "⚠️ Low lighting detected",
                style: TextStyle(
                  color: Colors.yellowAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 24),

          // ================= CAMERA CIRCLE =================
          SizedBox(
            height: 300,
            width: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // -------- CAMERA CIRCLE --------
                ClipOval(
                  child: SizedBox(
                    height: 300,
                    width: 300,
                    child: _isCameraInitialized
                        ? FittedBox(
                            fit: BoxFit.cover, // 🔥 KEY FIX
                            child: SizedBox(
                              width:
                                  _cameraController!.value.previewSize!.height,
                              height:
                                  _cameraController!.value.previewSize!.width,
                              child: CameraPreview(_cameraController!),
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                // -------- BORDER INDICATOR --------
                Container(
                  height: 300,
                  width: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _error == null
                          ? Colors.greenAccent
                          : Colors.redAccent,
                      width: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isCapturing ? null : _captureAndRegisterFace,
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

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

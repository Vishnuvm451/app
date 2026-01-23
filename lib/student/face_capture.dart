import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/auth/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FaceCapturePage extends StatefulWidget {
  final String admissionNo;
  final String studentName;

  const FaceCapturePage({
    super.key,
    required this.admissionNo,
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

  // 🔧 UPDATE THIS
  // Emulator: http://10.0.2.2:8000
  // Real device: http://<PC_IP>:8000
  static const String _apiBaseUrl = "https://darzo-backend-api.onrender.com";

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  // ===================================================
  // INITIALIZE FRONT CAMERA
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
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.setExposureMode(ExposureMode.auto);

      if (!mounted) return;

      setState(() => _isCameraInitialized = true);

      _checkLighting();
    } catch (e) {
      setState(() {
        _error = "Camera initialization failed";
      });
    }
  }

  // ===================================================
  // LIGHTING CHECK (SAFE HEURISTIC)
  // ===================================================
  Future<void> _checkLighting() async {
    try {
      final step = await _cameraController!.getExposureOffsetStepSize();
      setState(() {
        _isLightingGood = step > 0.01;
      });
    } catch (_) {
      setState(() {
        _isLightingGood = true;
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
      final user = FirebaseAuth.instance.currentUser; // Get current user

      if (user == null) throw Exception("User not logged in");

      // ---------- BACKEND ----------
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/register"),
      );

      // ✅ FIX: Add both admission_no AND auth_uid
      request.fields['admission_no'] = widget.admissionNo;
      request.fields['auth_uid'] = user.uid; // <--- THIS WAS MISSING

      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      // Add timeout to prevent infinite loading
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception("Connection timed out. Check IP/Server.");
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        // Print detailed error for debugging
        print("Server Error: ${response.body}");
        throw Exception("Registration failed: ${response.body}");
      }

      // ---------- FIRESTORE ----------
      await FirebaseFirestore.instance
          .collection('student')
          .doc(widget.admissionNo)
          .update({
            'face_enabled': true,
            'face_registered_at': FieldValue.serverTimestamp(),
          });

      // ---------- LOGOUT ----------
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Face registered successfully"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll("Exception:", "").trim();
      });
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // ===================================================
  // UI (UPDATED WITH BACK BUTTON LOGIC)
  // ===================================================
  @override
  Widget build(BuildContext context) {
    final bool isOk = _error == null && _isLightingGood;

    // ✅ WRAP SCAFFOLD IN POPSCOPE
    return PopScope(
      canPop: false, // 🔒 Prevent default closing
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 🔄 Navigate explicitly to Login Page
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (_) => false,
        );
      },
      child: Scaffold(
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
          elevation: 0,
          // ✅ Add a manual Back Button too, just in case
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (_) => false,
              );
            },
          ),
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
                  ClipOval(
                    child: SizedBox(
                      height: 300,
                      width: 300,
                      child: _isCameraInitialized
                          ? FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _cameraController!
                                    .value
                                    .previewSize!
                                    .height,
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

                  Container(
                    height: 300,
                    width: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOk ? Colors.greenAccent : Colors.redAccent,
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
      ),
    );
  }
}

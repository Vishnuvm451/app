import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert'; // For JSON decoding

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  // ---------------- STATE ----------------
  bool isLoading = true;
  bool isVerifying = false;
  String? error;
  String? statusMessage;

  String? studentId;
  String? admissionNo; // We need this to verify identity
  String? classId;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  DocumentSnapshot<Map<String, dynamic>>? activeSession;

  // 🔧 API URL (Must match FaceCapturePage)
  static const String _apiBaseUrl = "http://10.70.229.181";

  @override
  void initState() {
    super.initState();
    _loadDataAndCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // ===================================================
  // 1. LOAD DATA & INIT CAMERA
  // ===================================================
  Future<void> _loadDataAndCamera() async {
    try {
      studentId = FirebaseAuth.instance.currentUser?.uid;
      if (studentId == null) throw "User not logged in";

      // 1. Get Student Details (Need Admission No)
      final studentSnap = await FirebaseFirestore.instance
          .collection('student')
          .doc(
            studentId,
          ) // This might be AuthUID or AdmissionNo depending on your schema
          .get();

      // If doc ID is not AuthUID, we query by field
      DocumentSnapshot studentDoc = studentSnap;
      if (!studentDoc.exists) {
        final q = await FirebaseFirestore.instance
            .collection('student')
            .where('authUid', isEqualTo: studentId)
            .limit(1)
            .get();
        if (q.docs.isEmpty) throw "Student profile not found";
        studentDoc = q.docs.first;
      }

      final data = studentDoc.data() as Map<String, dynamic>;
      classId = data['classId'];
      admissionNo = data['admissionNo'] ?? studentDoc.id; // Fallback to ID

      // 2. Get Active Session
      final sessionQuery = await FirebaseFirestore.instance
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionQuery.docs.isEmpty) throw "No active attendance session";
      activeSession = sessionQuery.docs.first;

      // 3. Init Camera
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
    } catch (e) {
      error = e.toString().replaceAll("Exception:", "").trim();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ===================================================
  // 2. VERIFY FACE (PYTHON API)
  // ===================================================
  Future<void> _scanAndVerify() async {
    if (isVerifying || !_isCameraInitialized) return;

    setState(() {
      isVerifying = true;
      statusMessage = "Scanning face...";
    });

    try {
      // 1. Capture Image
      final image = await _cameraController!.takePicture();

      // 2. Send to Python Backend
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/verify"),
      );

      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final result = jsonDecode(response.body);

      if (response.statusCode != 200 || result['success'] != true) {
        throw result['message'] ?? "Verification failed";
      }

      // 3. Check Identity Match
      // Python returns the "Admission Number" of the face it found.
      // We must check if that matches THIS student's admission number.
      final String matchedAdmission = result['admissionNo'].toString();

      if (matchedAdmission != admissionNo) {
        throw "Face mismatch! You are not $admissionNo";
      }

      // 4. Mark Attendance
      await _markAttendanceInFirestore();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          isVerifying = false;
          statusMessage = null;
        });
      }
    }
  }

  // ===================================================
  // 3. MARK IN FIRESTORE
  // ===================================================
  Future<void> _markAttendanceInFirestore() async {
    final sessionId = activeSession!.id;
    final now = DateTime.now();

    // Check if already marked (Optimization)
    final existing = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(sessionId)
        .collection('student')
        .doc(studentId)
        .get();

    if (existing.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You have already marked attendance!")),
      );
      Navigator.pop(context);
      return;
    }

    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(sessionId)
        .collection('student')
        .doc(studentId)
        .set({
          'studentId': studentId,
          'admissionNo': admissionNo,
          'status': 'present',
          'method': 'face',
          'markedAt': FieldValue.serverTimestamp(),
          'deviceTime': now.toIso8601String(),
        });

    if (!mounted) return;

    // Success UI
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 60),
            SizedBox(height: 10),
            Text("Present!"),
          ],
        ),
        content: const Text(
          "Your attendance has been marked successfully.",
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close Dialog
              Navigator.pop(context); // Close Page
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // UI
  // ===================================================
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 20),
                Text(error!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Go Back"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scan Face"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          // 1. Camera Preview
          if (_isCameraInitialized)
            Center(child: CameraPreview(_cameraController!)),

          // 2. Overlay (Scanning Frame)
          Center(
            child: Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isVerifying ? Colors.orange : Colors.greenAccent,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: isVerifying
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : null,
            ),
          ),

          // 3. Scan Button
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: isVerifying ? null : _scanAndVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                isVerifying ? "VERIFYING..." : "SCAN & MARK ATTENDANCE",
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // 4. Status Text
          if (statusMessage != null)
            Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Text(
                statusMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

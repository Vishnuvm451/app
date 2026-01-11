import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  // ---------------- STATE ----------------
  bool isLoading = true;
  bool isVerifying = false;
  bool isSessionActive = false;

  String? error;
  String? statusMessage;

  String? studentId;
  String? admissionNo;
  String? classId;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;

  DocumentSnapshot<Map<String, dynamic>>? activeSession;

  // 🔧 Backend API
  static const String _apiBaseUrl = "http://10.70.229.181:8000";

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
  // 1. LOAD STUDENT + CHECK SESSION + INIT CAMERA
  // ===================================================
  Future<void> _loadDataAndCamera() async {
    try {
      studentId = FirebaseAuth.instance.currentUser?.uid;
      if (studentId == null) throw "User not logged in";

      // ---------------- STUDENT DATA ----------------
      final studentSnap = await FirebaseFirestore.instance
          .collection('student')
          .doc(studentId)
          .get();

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
      admissionNo = data['admissionNo'] ?? studentDoc.id;

      // ---------------- ATTENDANCE SESSION ----------------
      final sessionQuery = await FirebaseFirestore.instance
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionQuery.docs.isNotEmpty) {
        activeSession = sessionQuery.docs.first;
        isSessionActive = true;
      } else {
        isSessionActive = false;
      }

      // ---------------- CAMERA ----------------
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

      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      error = e.toString().replaceAll("Exception:", "").trim();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ===================================================
  // 2. FACE SCAN + VERIFY
  // ===================================================
  Future<void> _scanAndVerify() async {
    if (!isSessionActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⏳ Please wait for the teacher to start attendance session",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (isVerifying || !_isCameraInitialized) return;

    setState(() {
      isVerifying = true;
      statusMessage = "Scanning face...";
    });

    try {
      // Capture image
      final image = await _cameraController!.takePicture();

      // Send to backend
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$_apiBaseUrl/face/verify"),
      );

      request.files.add(await http.MultipartFile.fromPath('image', image.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final result = jsonDecode(response.body);

      if (response.statusCode != 200 || result['success'] != true) {
        throw result['message'] ?? "Face verification failed";
      }

      final matchedAdmission = result['admissionNo'].toString();

      if (matchedAdmission != admissionNo) {
        throw "Face mismatch! This face does not belong to you.";
      }

      // Mark attendance
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
  // 3. FIRESTORE WRITE
  // ===================================================
  Future<void> _markAttendanceInFirestore() async {
    final sessionId = activeSession!.id;

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
        });

    if (!mounted) return;

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
              Navigator.pop(context);
              Navigator.pop(context);
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 60, color: Colors.red),
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
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Face Attendance"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          if (_isCameraInitialized)
            Center(child: CameraPreview(_cameraController!)),

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

          if (!isSessionActive)
            const Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Text(
                "Waiting for teacher to start attendance session",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  backgroundColor: Colors.black54,
                ),
              ),
            ),

          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: (!isSessionActive || isVerifying)
                  ? null
                  : _scanAndVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                !isSessionActive
                    ? "WAITING FOR TEACHER"
                    : (isVerifying ? "VERIFYING..." : "SCAN & MARK ATTENDANCE"),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          if (statusMessage != null)
            Positioned(
              top: 90,
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

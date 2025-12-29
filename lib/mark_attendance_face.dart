import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  bool isLoading = true;
  String? error;

  String? studentId;
  String? classId;

  DocumentSnapshot<Map<String, dynamic>>? activeSession;

  @override
  void initState() {
    super.initState();
    _loadStudentAndSession();
  }

  // ===================================================
  // LOAD STUDENT + ACTIVE ATTENDANCE SESSION
  // ===================================================
  Future<void> _loadStudentAndSession() async {
    try {
      studentId = FirebaseAuth.instance.currentUser?.uid;

      if (studentId == null) {
        error = "User not logged in";
        return;
      }

      // ---------- STUDENT ----------
      final studentSnap = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentSnap.exists) {
        error = "Student profile not found";
        return;
      }

      classId = studentSnap.data()!['classId'];

      if (classId == null) {
        error = "Class not assigned";
        return;
      }

      // ---------- ACTIVE SESSION ----------
      final sessionQuery = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionQuery.docs.isEmpty) {
        error = "No active attendance session";
        return;
      }

      activeSession = sessionQuery.docs.first;
    } catch (e) {
      error = "Failed to load attendance session";
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ===================================================
  // FACE VERIFICATION (API HOOK)
  // ===================================================
  Future<bool> _verifyFace() async {
    /*
      🔌 HERE IS WHERE PYTHON API WILL CONNECT

      Steps later:
      1. Open camera
      2. Capture image
      3. Send to Python FastAPI
      4. Receive match: true / false
    */

    await Future.delayed(const Duration(seconds: 2));

    return true; // TEMP: assume success
  }

  // ===================================================
  // MARK ATTENDANCE
  // ===================================================
  Future<void> _markAttendance() async {
    if (activeSession == null || studentId == null) return;

    setState(() {
      isLoading = true;
      error = null;
    });

    final verified = await _verifyFace();

    if (!verified) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = "Face verification failed";
      });
      return;
    }

    try {
      final sessionId = activeSession!.id;

      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(sessionId)
          .collection('students')
          .doc(studentId)
          .set({
            'studentId': studentId,
            'status': 'present',
            'method': 'face',
            'markedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Attendance marked successfully ✅"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = "Failed to mark attendance";
        isLoading = false;
      });
    }
  }

  // ===================================================
  // UI
  // ===================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mark Attendance"), centerTitle: true),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : error != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.face, size: 90, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    "Face Recognition Attendance",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Scan Face & Mark Attendance"),
                    onPressed: _markAttendance,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

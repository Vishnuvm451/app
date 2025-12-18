import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  bool isLoading = false;
  String? error;

  String? studentId;
  String? classId;
  String? departmentId;

  DocumentSnapshot? activeSession;

  @override
  void initState() {
    super.initState();
    _loadStudentAndSession();
  }

  // --------------------------------------------------
  // LOAD STUDENT + ACTIVE SESSION
  // --------------------------------------------------
  Future<void> _loadStudentAndSession() async {
    setState(() => isLoading = true);

    try {
      studentId = FirebaseAuth.instance.currentUser!.uid;

      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(studentId)
          .get();

      classId = studentDoc['classId'];
      departmentId = studentDoc['departmentId'];

      // 🔥 Find ACTIVE attendance session for this class
      final sessionSnap = await FirebaseFirestore.instance
          .collection('attendance_sessions')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionSnap.docs.isEmpty) {
        error = "No active attendance session";
      } else {
        activeSession = sessionSnap.docs.first;
      }
    } catch (e) {
      error = "Error loading attendance session";
    }

    if (mounted) setState(() => isLoading = false);
  }

  // --------------------------------------------------
  // FACE + LOCATION + TIME CHECK (SIMPLIFIED)
  // --------------------------------------------------
  Future<bool> _verifyFaceAndLocation() async {
    // 🔥 PLACEHOLDER
    // 1. Capture image from camera
    // 2. Send to Face API
    // 3. Get match = true / false
    // 4. Check GPS radius

    await Future.delayed(const Duration(seconds: 2));

    return true; // Assume success for now
  }

  // --------------------------------------------------
  // MARK ATTENDANCE
  // --------------------------------------------------
  Future<void> _markAttendance() async {
    if (activeSession == null) return;

    setState(() => isLoading = true);

    final verified = await _verifyFaceAndLocation();

    if (!verified) {
      setState(() {
        error = "Face or location verification failed";
        isLoading = false;
      });
      return;
    }

    // 🔥 Save attendance record
    await FirebaseFirestore.instance.collection('attendance_records').add({
      'sessionId': activeSession!.id,
      'studentId': studentId,
      'status': 'present',
      'markedBy': 'face',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Attendance marked successfully")),
    );

    Navigator.pop(context);
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mark Attendance")),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : error != null
            ? Text(error!, style: const TextStyle(color: Colors.red))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.face, size: 80, color: Colors.blue),
                  const SizedBox(height: 16),
                  const Text(
                    "Face Recognition Attendance",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _markAttendance,
                    child: const Text("Scan Face & Mark Attendance"),
                  ),
                ],
              ),
      ),
    );
  }
}

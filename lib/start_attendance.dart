import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherAttendanceSessionPage extends StatefulWidget {
  const TeacherAttendanceSessionPage({super.key});

  @override
  State<TeacherAttendanceSessionPage> createState() =>
      _TeacherAttendanceSessionPageState();
}

class _TeacherAttendanceSessionPageState
    extends State<TeacherAttendanceSessionPage> {
  String? classId;
  String sessionType = "morning";
  bool isLoading = false;

  bool isApproved = false;
  bool setupCompleted = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  // --------------------------------------------------
  // LOAD TEACHER PROFILE
  // --------------------------------------------------
  Future<void> _loadTeacherProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await _db.collection('teachers').doc(user.uid).get();
    if (!snap.exists) return;

    final data = snap.data()!;

    isApproved = data['isApproved'] == true;
    setupCompleted = data['setupCompleted'] == true;

    if (!isApproved) {
      _showSnack("Your account is not approved");
      if (mounted) Navigator.pop(context);
      return;
    }

    if (!setupCompleted) {
      _showSnack("Complete setup before starting attendance");
      if (mounted) Navigator.pop(context);
      return;
    }

    if (!mounted) return;
    setState(() {
      classId = data['classId']; // 🔒 lock class
    });
  }

  // --------------------------------------------------
  // START SESSION
  // --------------------------------------------------
  Future<void> _startSession() async {
    if (classId == null) {
      _showSnack("Class not assigned");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isLoading = true);

    final today = DateTime.now();
    final date =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final sessionId = "${classId}_$date\_$sessionType";

    try {
      final ref = _db.collection('attendance_sessions').doc(sessionId);

      final snap = await ref.get();

      if (snap.exists && snap['isActive'] == true) {
        _showSnack("Session already active");
        return;
      }

      // 🔒 ensure no other active session for same class today
      final activeQuery = await _db
          .collection('attendance_sessions')
          .where('classId', isEqualTo: classId)
          .where('date', isEqualTo: date)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (activeQuery.docs.isNotEmpty) {
        _showSnack("Another session is already active");
        return;
      }

      await ref.set({
        'classId': classId,
        'date': date,
        'sessionType': sessionType,
        'isActive': true,
        'startedBy': user.uid,
        'startedAt': FieldValue.serverTimestamp(),
      });

      _showSnack("Attendance session started", success: true);
    } catch (e) {
      _showSnack("Failed to start session");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --------------------------------------------------
  // STOP SESSION
  // --------------------------------------------------
  Future<void> _stopSession() async {
    if (classId == null) {
      _showSnack("Class not assigned");
      return;
    }

    final today = DateTime.now();
    final date =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final sessionId = "${classId}_$date\_$sessionType";

    try {
      final ref = _db.collection('attendance_sessions').doc(sessionId);

      final snap = await ref.get();

      if (!snap.exists || snap['isActive'] != true) {
        _showSnack("No active session to stop");
        return;
      }

      await ref.update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
      });

      _showSnack("Attendance session stopped", success: true);
    } catch (e) {
      _showSnack("Failed to stop session");
    }
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (classId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Session"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _classInfo(),
            const SizedBox(height: 20),
            _sessionTypeSelector(),
            const SizedBox(height: 40),
            _actionButtons(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // CLASS INFO (LOCKED)
  // --------------------------------------------------
  Widget _classInfo() {
    return TextField(
      enabled: false,
      decoration: InputDecoration(
        labelText: "Class",
        prefixIcon: const Icon(Icons.class_),
        border: const OutlineInputBorder(),
        hintText: classId,
      ),
    );
  }

  // --------------------------------------------------
  // SESSION TYPE
  // --------------------------------------------------
  Widget _sessionTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: RadioListTile<String>(
            value: "morning",
            groupValue: sessionType,
            title: const Text("Morning"),
            onChanged: (v) => setState(() => sessionType = v!),
          ),
        ),
        Expanded(
          child: RadioListTile<String>(
            value: "afternoon",
            groupValue: sessionType,
            title: const Text("Afternoon"),
            onChanged: (v) => setState(() => sessionType = v!),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // BUTTONS
  // --------------------------------------------------
  Widget _actionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : _startSession,
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    "START ATTENDANCE",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _stopSession,
            child: const Text(
              "STOP ATTENDANCE",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // SNACK
  // --------------------------------------------------
  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

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

    final snap = await _db.collection('teacher').doc(user.uid).get();
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
      classId = data['classId']; // 🔒 locked class
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

    final today = _todayId();
    final sessionId = "${classId}_$today\_$sessionType";

    try {
      final ref = _db.collection('attendance_session').doc(sessionId);

      final snap = await ref.get();
      if (snap.exists && snap['isActive'] == true) {
        _showSnack("Session already active");
        return;
      }

      // Ensure only ONE active session per class per day
      final activeQuery = await _db
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('date', isEqualTo: today)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (activeQuery.docs.isNotEmpty) {
        _showSnack("Another session is already active");
        return;
      }

      await ref.set({
        'classId': classId,
        'date': today,
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
  // STOP SESSION + FINALIZE ATTENDANCE
  // --------------------------------------------------
  Future<void> _stopSession() async {
    if (classId == null) {
      _showSnack("Class not assigned");
      return;
    }

    final today = _todayId();
    final sessionId = "${classId}_$today\_$sessionType";

    try {
      final ref = _db.collection('attendance_session').doc(sessionId);
      final snap = await ref.get();

      if (!snap.exists || snap['isActive'] != true) {
        _showSnack("No active session to stop");
        return;
      }

      await ref.update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
      });

      // ✅ FINALIZE DAILY ATTENDANCE
      await _finalizeAttendance(classId!);

      _showSnack("Attendance finalized", success: true);
    } catch (e) {
      _showSnack("Failed to stop session");
    }
  }

  // --------------------------------------------------
  // FINALIZE DAILY ATTENDANCE
  // --------------------------------------------------
  Future<void> _finalizeAttendance(String classId) async {
    final today = _todayId();
    final finalDocId = '${classId}_$today';

    final finalRef = _db.collection('attendance_final').doc(finalDocId);

    // 1️⃣ Parent doc
    await finalRef.set({
      'classId': classId,
      'date': today,
      'finalizedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2️⃣ Load students of class
    final studentsSnap = await _db
        .collection('student')
        .where('classId', isEqualTo: classId)
        .get();

    if (studentsSnap.docs.isEmpty) return;

    // 3️⃣ Load session attendance
    final morningId = '${classId}_${today}_morning';
    final afternoonId = '${classId}_${today}_afternoon';

    final morningSnap = await _db
        .collection('attendance')
        .doc(morningId)
        .collection('student')
        .get();

    final afternoonSnap = await _db
        .collection('attendance')
        .doc(afternoonId)
        .collection('student')
        .get();

    final morningMap = {for (var d in morningSnap.docs) d.id: true};
    final afternoonMap = {for (var d in afternoonSnap.docs) d.id: true};

    // 4️⃣ Compute final status
    final batch = _db.batch();

    for (final stu in studentsSnap.docs) {
      final studentId = stu.id;

      final bool m = morningMap[studentId] == true;
      final bool a = afternoonMap[studentId] == true;

      String status;
      if (m && a) {
        status = 'present';
      } else if (m || a) {
        status = 'half-day';
      } else {
        status = 'absent';
      }

      batch.set(finalRef.collection('student').doc(studentId), {
        'studentId': studentId,
        'status': status,
        'computedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
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

// --------------------------------------------------
// DATE HELPER
// --------------------------------------------------
String _todayId() {
  final now = DateTime.now();
  return '${now.year}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

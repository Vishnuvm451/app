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

  // Theme Color
  final Color primaryBlue = const Color(0xFF2196F3);

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

    try {
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

      if (mounted) {
        setState(() {
          classId = data['classId']; // 🔒 locked class
        });
      }
    } catch (e) {
      print("Profile Load Error: $e");
    }
  }

  // --------------------------------------------------
  // START SESSION (FIXED WITH BATCH)
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
    final sessionId = "${classId}_${today}_$sessionType";

    try {
      final sessionRef = _db.collection('attendance_session').doc(sessionId);
      final attendanceRef = _db.collection('attendance').doc(sessionId);

      // 1. Check if session exists using a Fresh Transaction or Get
      final sessionSnap = await sessionRef.get();

      if (sessionSnap.exists && sessionSnap.data()!['isActive'] == true) {
        _showSnack("Session already active");
        return;
      }

      // 2. Check for ANY other active session for this class today
      // (Prevent Morning and Afternoon running at same time)
      final activeQuery = await _db
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('date', isEqualTo: today)
          .where('isActive', isEqualTo: true)
          .get();

      if (activeQuery.docs.isNotEmpty) {
        // If the found active session is NOT the one we are trying to start
        if (activeQuery.docs.first.id != sessionId) {
          _showSnack("Another session is already active");
          return;
        }
      }

      // 3. USE BATCH WRITE (Fixes "Failed but started" bug)
      // This ensures both docs are created, or neither is.
      WriteBatch batch = _db.batch();

      batch.set(sessionRef, {
        'classId': classId,
        'date': today,
        'sessionType': sessionType,
        'isActive': true,
        'startedBy': user.uid,
        'startedAt': FieldValue.serverTimestamp(),
      });

      batch.set(attendanceRef, {
        'classId': classId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      _showSnack("Attendance session started", success: true);
    } catch (e) {
      print("Start Session Error: $e"); // Check Console for red errors
      _showSnack("Failed to start session: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --------------------------------------------------
  // STOP SESSION (FIXED LOGIC ORDER)
  // --------------------------------------------------
  Future<void> _stopSession() async {
    if (classId == null) {
      _showSnack("Class not assigned");
      return;
    }

    setState(() => isLoading = true);

    final today = _todayId();
    final sessionId = "${classId}_${today}_$sessionType";

    try {
      final ref = _db.collection('attendance_session').doc(sessionId);
      final snap = await ref.get();

      if (!snap.exists || snap.data()!['isActive'] != true) {
        _showSnack("No active session to stop");
        return;
      }

      // 1. Finalize Attendance FIRST (Calculate presence)
      await _finalizeAttendance(classId!);

      // 2. THEN Close the Session
      await ref.update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
      });

      _showSnack("Attendance finalized", success: true);
    } catch (e) {
      print("Stop Session Error: $e");
      _showSnack("Failed to stop session: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --------------------------------------------------
  // FINALIZE ATTENDANCE
  // --------------------------------------------------
  Future<void> _finalizeAttendance(String classId) async {
    final today = _todayId();
    final finalDocId = '${classId}_$today';

    final finalRef = _db.collection('attendance_final').doc(finalDocId);

    // Create the daily report doc
    await finalRef.set({
      'classId': classId,
      'date': today,
      'finalizedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Get all students in this class
    final studentsSnap = await _db
        .collection('student')
        .where('classId', isEqualTo: classId)
        .get();

    if (studentsSnap.docs.isEmpty) return;

    final morningId = '${classId}_${today}_morning';
    final afternoonId = '${classId}_${today}_afternoon';

    // Fetch Morning Data
    final morningSnap = await _db
        .collection('attendance')
        .doc(morningId)
        .collection('student')
        .get();

    // Fetch Afternoon Data
    final afternoonSnap = await _db
        .collection('attendance')
        .doc(afternoonId)
        .collection('student')
        .get();

    // Map for fast lookup
    final morningMap = {for (var d in morningSnap.docs) d.id: true};
    final afternoonMap = {for (var d in afternoonSnap.docs) d.id: true};

    // Prepare Batch for Student Status Updates
    // Note: Firestore batch limit is 500. If class > 500, needs chunking.
    final batch = _db.batch();

    for (final stu in studentsSnap.docs) {
      final studentId = stu.id;

      final bool m = morningMap[studentId] == true;
      final bool a = afternoonMap[studentId] == true;

      String status;
      if (m && a) {
        status = 'present'; // Both sessions present
      } else if (m || a) {
        status = 'half-day'; // One session present
      } else {
        status = 'absent'; // Neither
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
  // UI (UNCHANGED)
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (classId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Attendance Session",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _classInfoCard(),
            const SizedBox(height: 24),
            _sessionTypeCard(),
            const SizedBox(height: 40),
            _actionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _classInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.class_, color: primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Active Class",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                classId ?? "Unknown",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sessionTypeCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              "Select Session",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          const Divider(height: 1),
          _radioOption("Morning", "morning", Icons.wb_sunny_rounded),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _radioOption("Afternoon", "afternoon", Icons.wb_twilight_rounded),
        ],
      ),
    );
  }

  Widget _radioOption(String title, String value, IconData icon) {
    final bool isSelected = sessionType == value;
    return RadioListTile<String>(
      value: value,
      groupValue: sessionType,
      activeColor: primaryBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          Icon(icon, color: isSelected ? primaryBlue : Colors.grey, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? primaryBlue : Colors.black87,
            ),
          ),
        ],
      ),
      onChanged: (v) => setState(() => sessionType = v!),
    );
  }

  Widget _actionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isLoading ? null : _startSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              elevation: 4,
              shadowColor: primaryBlue.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill, size: 28),
                      SizedBox(width: 10),
                      Text(
                        "START ATTENDANCE",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.shade200, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: isLoading ? null : _stopSession,
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.red,
                      strokeWidth: 3,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop_circle_outlined, size: 28),
                      SizedBox(width: 10),
                      Text(
                        "STOP ATTENDANCE",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
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

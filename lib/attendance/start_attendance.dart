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
  static const Duration SESSION_DURATION = Duration(hours: 4);

  String? classId;
  String sessionType = "morning";
  bool isLoading = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color bgLight = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  // --------------------------------------------------
  Future<void> _loadTeacherProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = await _db
        .collection('teacher')
        .where('authUid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final data = query.docs.first.data();

    if (data['isApproved'] != true || data['setupCompleted'] != true) {
      _showSnack("Complete approval & setup first");
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      classId = (data['classIds'] as List).first;
    });
  }

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

      await _db.runTransaction((tx) async {
        final snap = await tx.get(sessionRef);

        if (snap.exists && snap.data()!['isActive'] == true) {
          final expiresAt = snap.data()!['expiresAt'] as Timestamp?;
          if (expiresAt != null && expiresAt.toDate().isAfter(DateTime.now())) {
            throw Exception("Session already active");
          }
        }

        tx.set(sessionRef, {
          'classId': classId,
          'date': today,
          'sessionType': sessionType,
          'isActive': true,
          'startedBy': user.uid,
          'startedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(DateTime.now().add(SESSION_DURATION)),
        });

        tx.set(attendanceRef, {
          'classId': classId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      _showSnack("Attendance session started", success: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll("Exception:", "").trim());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --------------------------------------------------
  Future<void> _stopSession() async {
    if (classId == null) return;

    setState(() => isLoading = true);

    final today = _todayId();
    final sessionId = "${classId}_${today}_$sessionType";

    try {
      final ref = _db.collection('attendance_session').doc(sessionId);
      final snap = await ref.get();

      if (!snap.exists || snap.data()!['isActive'] != true) {
        _showSnack("No active session");
        return;
      }

      await _finalizeAttendance(classId!);

      await ref.update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
        'endedReason': 'manual_or_expired',
      });

      _showSnack("Attendance finalized", success: true);
    } catch (_) {
      _showSnack("Failed to stop session");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --------------------------------------------------
  Future<void> _finalizeAttendance(String classId) async {
    final today = _todayId();
    final finalDocId = '${classId}_$today';
    final finalRef = _db.collection('attendance_final').doc(finalDocId);

    await finalRef.set({
      'classId': classId,
      'date': today,
      'finalizedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final studentsSnap = await _db
        .collection('student')
        .where('classId', isEqualTo: classId)
        .get();

    final morningSnap = await _db
        .collection('attendance')
        .doc('${classId}_${today}_morning')
        .collection('student')
        .get();

    final afternoonSnap = await _db
        .collection('attendance')
        .doc('${classId}_${today}_afternoon')
        .collection('student')
        .get();

    final morningMap = {for (var d in morningSnap.docs) d.id: true};
    final afternoonMap = {for (var d in afternoonSnap.docs) d.id: true};

    final existingFinal = await finalRef.collection('student').get();
    final manualOverrides = {
      for (var d in existingFinal.docs)
        if (d['method'] == 'manual_override') d.id: true,
    };

    final batch = _db.batch();
    int count = 0;

    for (final stu in studentsSnap.docs) {
      final sid = stu.id;
      if (manualOverrides.containsKey(sid)) continue;

      final m = morningMap[sid] == true;
      final a = afternoonMap[sid] == true;

      final status = (m && a)
          ? 'present'
          : (m || a)
          ? 'half-day'
          : 'absent';

      batch.set(finalRef.collection('student').doc(sid), {
        'studentId': sid,
        'status': status,
        'method': 'auto_calc',
        'computedAt': FieldValue.serverTimestamp(),
      });

      count++;
      if (count >= 400) {
        await batch.commit();
        count = 0;
      }
    }

    if (count > 0) await batch.commit();
  }

  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (classId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "Attendance Session",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: primaryBlue),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Session auto-expires after 4 hours",
                      style: TextStyle(color: Colors.orange.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _card(_radio("Morning", "morning")),
            const SizedBox(height: 12),
            _card(_radio("Afternoon", "afternoon")),
            const SizedBox(height: 40),
            _btn("START ATTENDANCE", _startSession),
            const SizedBox(height: 16),
            _btn("STOP ATTENDANCE", _stopSession, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: child,
    );
  }

  Widget _radio(String title, String val) {
    return RadioListTile<String>(
      value: val,
      groupValue: sessionType,
      activeColor: primaryBlue,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      onChanged: (v) => setState(() => sessionType = v!),
    );
  }

  Widget _btn(String text, VoidCallback onTap, {bool danger = false}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: danger ? Colors.red : primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

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
String _todayId() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

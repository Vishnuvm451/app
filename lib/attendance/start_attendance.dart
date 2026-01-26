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
  bool isMorningActive = false;
  bool isAfternoonActive = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color bgLight = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  // ================= LOAD TEACHER PROFILE =================
  Future<void> _loadTeacherProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack("User not authenticated");
        if (mounted) Navigator.pop(context);
        return;
      }

      final query = await _db
          .collection('teacher')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showSnack("Teacher profile not found");
        if (mounted) Navigator.pop(context);
        return;
      }

      final data = query.docs.first.data();

      if (data['isApproved'] != true || data['setupCompleted'] != true) {
        _showSnack("Complete approval & setup first");
        if (mounted) Navigator.pop(context);
        return;
      }

      final classIds = data['classIds'] as List?;
      if (classIds == null || classIds.isEmpty) {
        _showSnack("No class assigned");
        if (mounted) Navigator.pop(context);
        return;
      }

      setState(() {
        classId = classIds.first as String;
      });

      // Load current session status
      _loadSessionStatus();
    } catch (e) {
      _showSnack("Error loading profile: $e");
    }
  }

  // ================= LOAD SESSION STATUS =================
  Future<void> _loadSessionStatus() async {
    if (classId == null) return;

    try {
      final today = _todayId();

      // Check morning session
      final morningDoc = await _db
          .collection('attendance_session')
          .doc('${classId}_${today}_morning')
          .get();

      final afternoonDoc = await _db
          .collection('attendance_session')
          .doc('${classId}_${today}_afternoon')
          .get();

      if (mounted) {
        setState(() {
          // Check if sessions exist AND are active AND not expired
          isMorningActive =
              morningDoc.exists &&
              morningDoc['isActive'] == true &&
              _isSessionValid(morningDoc);

          isAfternoonActive =
              afternoonDoc.exists &&
              afternoonDoc['isActive'] == true &&
              _isSessionValid(afternoonDoc);
        });
      }
    } catch (e) {
      print("❌ Error loading session status: $e");
    }
  }

  // ================= CHECK SESSION VALIDITY =================
  bool _isSessionValid(DocumentSnapshot doc) {
    try {
      final expiresAt = doc['expiresAt'] as Timestamp?;
      if (expiresAt == null) return false;

      final now = DateTime.now();
      final expireTime = expiresAt.toDate();

      return expireTime.isAfter(now);
    } catch (e) {
      return false;
    }
  }

  // ================= START SESSION =================
  Future<void> _startSession() async {
    if (classId == null) {
      _showSnack("Class not assigned");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack("User not authenticated");
      return;
    }

    // ✅ Check if session already active
    final today = _todayId();
    final sessionId = "${classId}_${today}_$sessionType";
    final sessionDoc = await _db
        .collection('attendance_session')
        .doc(sessionId)
        .get();

    if (sessionDoc.exists && sessionDoc['isActive'] == true) {
      final expiresAt = sessionDoc['expiresAt'] as Timestamp?;
      if (expiresAt != null && expiresAt.toDate().isAfter(DateTime.now())) {
        _showSnack("$sessionType session is already active");
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      final now = DateTime.now();
      final expiresAt = now.add(SESSION_DURATION);

      // ✅ Create session
      await _db.collection('attendance_session').doc(sessionId).set({
        'classId': classId,
        'date': today,
        'sessionType': sessionType,
        'isActive': true,
        'startedBy': user.uid,
        'startedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'endedAt': null,
      });

      // ✅ Initialize attendance document
      await _db.collection('attendance').doc(sessionId).set({
        'classId': classId,
        'date': today,
        'sessionType': sessionType,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnack("✅ $sessionType session started", success: true);

      // ✅ Reload session status
      _loadSessionStatus();
    } catch (e) {
      _showSnack("❌ Error starting session: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= STOP SESSION =================
  Future<void> _stopSession() async {
    if (classId == null) {
      _showSnack("Class not assigned");
      return;
    }

    final today = _todayId();
    final sessionId = "${classId}_${today}_$sessionType";

    // Check if session exists
    final sessionDoc = await _db
        .collection('attendance_session')
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists || sessionDoc['isActive'] != true) {
      _showSnack("❌ No active $sessionType session");
      return;
    }

    setState(() => isLoading = true);

    try {
      // ✅ Step 1: Mark session as inactive
      await _db.collection('attendance_session').doc(sessionId).update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': 'manual_stop',
      });

      _showSnack("✅ $sessionType session stopped", success: true);

      // ✅ Step 2: Calculate and finalize attendance (async, don't block UI)
      _finalizeAttendanceAsync(classId!, today);

      // ✅ Reload session status
      _loadSessionStatus();
    } catch (e) {
      _showSnack("❌ Error stopping session: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= FINALIZE ATTENDANCE (Background) =================
  Future<void> _finalizeAttendanceAsync(String classId, String today) async {
    try {
      print("📊 Starting attendance finalization...");

      final finalDocId = '${classId}_$today';
      final finalRef = _db.collection('attendance_final').doc(finalDocId);

      // ✅ Get all students in class
      final studentsSnap = await _db
          .collection('student')
          .where('classId', isEqualTo: classId)
          .get();

      print("📍 Total students: ${studentsSnap.docs.length}");

      if (studentsSnap.docs.isEmpty) {
        print("⚠️ No students found in class");
        return;
      }

      // ✅ Get morning attendance records
      final morningSnap = await _db
          .collection('attendance')
          .doc('${classId}_${today}_morning')
          .collection('student')
          .get();

      // ✅ Get afternoon attendance records
      final afternoonSnap = await _db
          .collection('attendance')
          .doc('${classId}_${today}_afternoon')
          .collection('student')
          .get();

      print("📍 Morning attendance: ${morningSnap.docs.length}");
      print("📍 Afternoon attendance: ${afternoonSnap.docs.length}");

      // ✅ Create lookup maps
      final morningMap = {for (var d in morningSnap.docs) d.id: true};
      final afternoonMap = {for (var d in afternoonSnap.docs) d.id: true};

      // ✅ Get existing manual overrides
      final existingFinal = await finalRef.collection('student').get();
      final manualOverrides = {
        for (var d in existingFinal.docs)
          if (d['method'] == 'manual_override') d.id: true,
      };

      print("📍 Manual overrides: ${manualOverrides.length}");

      // ✅ Calculate attendance for each student
      final batch = _db.batch();
      int processedCount = 0;

      for (final stu in studentsSnap.docs) {
        final studentId = stu.id;

        // ✅ Skip manual overrides (preserve teacher's manual entries)
        if (manualOverrides.containsKey(studentId)) {
          print("⏭️ Skipping $studentId (manual override)");
          continue;
        }

        // ✅ Check morning and afternoon attendance
        final morningPresent = morningMap.containsKey(studentId);
        final afternoonPresent = afternoonMap.containsKey(studentId);

        // ✅ Calculate status: present, half-day, absent
        String status;
        if (morningPresent && afternoonPresent) {
          status = 'present'; // Both sessions
        } else if (morningPresent || afternoonPresent) {
          status = 'half-day'; // One session only
        } else {
          status = 'absent'; // Neither session
        }

        print(
          "📝 $studentId: $status (M:$morningPresent, A:$afternoonPresent)",
        );

        // ✅ Add to batch
        batch.set(finalRef.collection('student').doc(studentId), {
          'studentId': studentId,
          'status': status,
          'morningPresent': morningPresent,
          'afternoonPresent': afternoonPresent,
          'method': 'auto_calc',
          'computedAt': FieldValue.serverTimestamp(),
        });

        processedCount++;

        // ✅ Commit batch every 500 records
        if (processedCount % 500 == 0) {
          await batch.commit();
          print("✅ Batch committed: $processedCount records");
        }
      }

      // ✅ Commit remaining records
      if (processedCount % 500 != 0) {
        await batch.commit();
        print("✅ Final batch committed");
      }

      // ✅ Update attendance_final document metadata
      await finalRef.set({
        'classId': classId,
        'date': today,
        'totalStudents': studentsSnap.docs.length,
        'presentCount': studentsSnap.docs
            .where(
              (s) =>
                  morningMap.containsKey(s.id) &&
                  afternoonMap.containsKey(s.id),
            )
            .length,
        'halfDayCount': studentsSnap.docs
            .where(
              (s) =>
                  (morningMap.containsKey(s.id) ||
                      afternoonMap.containsKey(s.id)) &&
                  !(morningMap.containsKey(s.id) &&
                      afternoonMap.containsKey(s.id)),
            )
            .length,
        'absentCount': studentsSnap.docs
            .where(
              (s) =>
                  !morningMap.containsKey(s.id) &&
                  !afternoonMap.containsKey(s.id),
            )
            .length,
        'status': 'finalized',
        'finalizedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("🎉 Attendance finalization complete");
    } catch (e) {
      print("❌ Finalization error: $e");
      _showSnack("⚠️ Finalization error (data may be incomplete): $e");
    }
  }

  // ================= BUILD UI =================
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
            // ✅ Information banner
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

            // ✅ Morning session selector with status indicator
            _card(
              _sessionRadio(
                title: "Morning",
                value: "morning",
                isActive: isMorningActive,
              ),
            ),
            const SizedBox(height: 12),

            // ✅ Afternoon session selector with status indicator
            _card(
              _sessionRadio(
                title: "Afternoon",
                value: "afternoon",
                isActive: isAfternoonActive,
              ),
            ),
            const SizedBox(height: 40),

            // ✅ Start session button
            _btn(
              "START ATTENDANCE",
              _startSession,
              isDisabled:
                  (sessionType == "morning" && isMorningActive) ||
                  (sessionType == "afternoon" && isAfternoonActive),
            ),
            const SizedBox(height: 16),

            // ✅ Stop session button (only enabled if session is active)
            _btn(
              "STOP ATTENDANCE",
              _stopSession,
              danger: true,
              isDisabled:
                  (sessionType == "morning" && !isMorningActive) ||
                  (sessionType == "afternoon" && !isAfternoonActive),
            ),
          ],
        ),
      ),
    );
  }

  // ================= SESSION RADIO WITH STATUS =================
  Widget _sessionRadio({
    required String title,
    required String value,
    required bool isActive,
  }) {
    return RadioListTile<String>(
      value: value,
      groupValue: sessionType,
      activeColor: primaryBlue,
      title: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "🔴 ACTIVE",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "⚫ INACTIVE",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onChanged: (v) => setState(() => sessionType = v!),
    );
  }

  // ================= CARD WRAPPER =================
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

  // ================= BUTTON =================
  Widget _btn(
    String text,
    VoidCallback onTap, {
    bool danger = false,
    bool isDisabled = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled
              ? Colors.grey.shade400
              : (danger ? Colors.red : primaryBlue),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: isLoading || isDisabled ? null : onTap,
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // ================= SNACKBAR =================
  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ================= UTILITY =================
String _todayId() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

import 'dart:async';
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
  static const Duration EXPIRY_CHECK_INTERVAL = Duration(seconds: 2);

  String? classId;
  String className = "";
  String sessionType = "morning";
  bool isLoading = false;
  bool isMorningActive = false;
  bool isAfternoonActive = false;
  bool isMorningCompleted = false;
  bool isAfternoonCompleted = false;

  // Timer displays
  String morningTimeLeft = "";
  String afternoonTimeLeft = "";
  String morningStudentsMarked = "0";
  String afternoonStudentsMarked = "0";

  // ✅ NEW: Local variables to store expiry times (prevents DB spam)
  DateTime? _morningExpiry;
  DateTime? _afternoonExpiry;

  Timer? _expiryTimer;
  Timer? _displayTimer;
  bool _hasActiveSession = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color bgLight = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
    _startExpiryTimer();
    _startDisplayTimer();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _displayTimer?.cancel();
    super.dispose();
  }

  // ================= START EXPIRY TIMER =================
  void _startExpiryTimer() {
    _expiryTimer = Timer.periodic(EXPIRY_CHECK_INTERVAL, (timer) {
      if (!mounted || classId == null) return;

      if (_hasActiveSession) {
        _checkAutoExpire();
      }
    });
  }

  // ================= DISPLAY TIMER (OPTIMIZED) =================
  // ✅ FIX: No longer calls DB every second. Does local math only.
  void _startDisplayTimer() {
    _displayTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _updateDisplayTimes();
    });
  }

  void _updateDisplayTimes() {
    if (classId == null) return;

    setState(() {
      // 1. Update Morning Timer locally
      if (_morningExpiry != null) {
        final remaining = _morningExpiry!.difference(DateTime.now());
        if (remaining.isNegative) {
          morningTimeLeft = "Expired";
          // Trigger refresh if it just expired
          if (isMorningActive) _loadSessionStatus();
        } else {
          morningTimeLeft = _formatDuration(remaining);
        }
      } else if (!isMorningActive) {
        // Keep empty or "Expired" if not active, handled in load status
      }

      // 2. Update Afternoon Timer locally
      if (_afternoonExpiry != null) {
        final remaining = _afternoonExpiry!.difference(DateTime.now());
        if (remaining.isNegative) {
          afternoonTimeLeft = "Expired";
          if (isAfternoonActive) _loadSessionStatus();
        } else {
          afternoonTimeLeft = _formatDuration(remaining);
        }
      } else if (!isAfternoonActive) {
        // Keep empty or "Expired"
      }
    });
  }

  // Helper to format time strings locally
  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String hours = twoDigits(d.inHours);
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inHours > 0) return "${hours}h ${minutes}m ${seconds}s";
    return "${minutes}m ${seconds}s";
  }

  String _todayId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ================= AUTO-EXPIRE CHECK =================
  Future<void> _checkAutoExpire() async {
    if (classId == null) return;
    final today = _todayId();

    try {
      if (isMorningActive) {
        final morningDoc = await _db
            .collection('attendance_session')
            .doc('${classId}_${today}_morning')
            .get();

        if (morningDoc.exists && !_isSessionValid(morningDoc)) {
          print("⏰ Morning session auto-expired");
          await _expireSession('morning', today);
        }
      }

      if (isAfternoonActive) {
        final afternoonDoc = await _db
            .collection('attendance_session')
            .doc('${classId}_${today}_afternoon')
            .get();

        if (afternoonDoc.exists && !_isSessionValid(afternoonDoc)) {
          print("⏰ Afternoon session auto-expired");
          await _expireSession('afternoon', today);
        }
      }
    } catch (e) {
      print("❌ Auto-expire check error: $e");
    }
  }

  // ================= EXPIRE SESSION =================
  Future<void> _expireSession(String type, String today) async {
    try {
      await _db
          .collection('attendance_session')
          .doc('${classId}_${today}_$type')
          .update({
            'isActive': false,
            'endedAt': FieldValue.serverTimestamp(),
            'endReason': 'auto_expired',
          });

      // Run finalization if afternoon session expired
      if (type == 'afternoon') {
        print("⏳ Auto-finalizing attendance...");
        await _finalizeAttendanceAsync(classId!, today);
      }

      if (mounted) {
        setState(() {
          if (type == 'morning') {
            isMorningActive = false;
            isMorningCompleted = true;
            morningTimeLeft = "Expired";
            _morningExpiry = null; // Clear timer
          } else {
            isAfternoonActive = false;
            isAfternoonCompleted = true;
            afternoonTimeLeft = "Expired";
            _afternoonExpiry = null; // Clear timer
          }
          _hasActiveSession = isMorningActive || isAfternoonActive;
        });

        _showSnack(
          "⏰ ${_capitalize(type)} session auto-expired",
          success: true,
        );
      }
    } catch (e) {
      print("❌ Error expiring session: $e");
    }
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

      await _loadClassName();
      _loadSessionStatus();
    } catch (e) {
      _showSnack("Error loading profile: $e");
    }
  }

  // ================= LOAD CLASS NAME =================
  Future<void> _loadClassName() async {
    if (classId == null) return;

    try {
      final classDoc = await _db.collection('class').doc(classId).get();

      if (classDoc.exists) {
        final data = classDoc.data();
        setState(() {
          className =
              data?['name'] ?? data?['className'] ?? _formatClassId(classId!);
        });
      } else {
        setState(() {
          className = _formatClassId(classId!);
        });
      }

      print("✅ Class name loaded: $className");
    } catch (e) {
      print("⚠️ Error loading class name: $e");
      setState(() {
        className = _formatClassId(classId!);
      });
    }
  }

  String _formatClassId(String id) {
    return id.replaceAll('_', ' ').toUpperCase();
  }

  // ================= LOAD SESSION STATUS (UPDATED) =================
  // ✅ FIX: Fetches student counts here instead of in the timer loop
  Future<void> _loadSessionStatus() async {
    if (classId == null) return;

    try {
      final today = _todayId();
      print("📍 Loading sessions for classId: '$classId', date: '$today'");

      // 1. Fetch Session Docs
      final morningDoc = await _db
          .collection('attendance_session')
          .doc('${classId}_${today}_morning')
          .get();

      final afternoonDoc = await _db
          .collection('attendance_session')
          .doc('${classId}_${today}_afternoon')
          .get();

      // 2. Fetch Student Counts (Efficiently)
      // Note: count() aggregation is cheaper but .get().length is fine for class sizes < 100
      final morningStudentsSnap = await _db
          .collection('attendance')
          .doc('${classId}_${today}_morning')
          .collection('student')
          .get();

      final afternoonStudentsSnap = await _db
          .collection('attendance')
          .doc('${classId}_${today}_afternoon')
          .collection('student')
          .get();

      if (mounted) {
        setState(() {
          // --- Morning Logic ---
          isMorningActive =
              morningDoc.exists &&
              morningDoc['isActive'] == true &&
              _isSessionValid(morningDoc);

          isMorningCompleted =
              morningDoc.exists && morningDoc['isActive'] == false;

          if (isMorningActive) {
            Timestamp? ts = morningDoc['expiresAt'];
            _morningExpiry = ts?.toDate();
          } else {
            _morningExpiry = null;
            morningTimeLeft = isMorningCompleted ? "" : "";
          }

          morningStudentsMarked = morningStudentsSnap.docs.length.toString();

          // --- Afternoon Logic ---
          isAfternoonActive =
              afternoonDoc.exists &&
              afternoonDoc['isActive'] == true &&
              _isSessionValid(afternoonDoc);

          isAfternoonCompleted =
              afternoonDoc.exists && afternoonDoc['isActive'] == false;

          if (isAfternoonActive) {
            Timestamp? ts = afternoonDoc['expiresAt'];
            _afternoonExpiry = ts?.toDate();
          } else {
            _afternoonExpiry = null;
            afternoonTimeLeft = isAfternoonCompleted ? "" : "";
          }

          afternoonStudentsMarked = afternoonStudentsSnap.docs.length
              .toString();

          _hasActiveSession = isMorningActive || isAfternoonActive;
        });

        // Auto-expire stale sessions
        if (morningDoc.exists &&
            morningDoc['isActive'] == true &&
            !_isSessionValid(morningDoc)) {
          _expireSession('morning', today);
        }

        if (afternoonDoc.exists &&
            afternoonDoc['isActive'] == true &&
            !_isSessionValid(afternoonDoc)) {
          _expireSession('afternoon', today);
        }
      }
    } catch (e) {
      print("❌ Error loading session status: $e");
    }
  }

  bool _isSessionValid(DocumentSnapshot doc) {
    try {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final dynamic expiresAtRaw = data['expiresAt'];

      if (expiresAtRaw == null) return false;
      if (expiresAtRaw is! Timestamp) return false;

      return expiresAtRaw.toDate().isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  // ================= START SESSION =================
  Future<void> _startSession() async {
    if (classId == null) return _showSnack("Class not assigned");

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _showSnack("User not authenticated");

    final today = _todayId();
    final sessionId = "${classId}_${today}_$sessionType";

    print("🚀 Starting session: $sessionId");

    final sessionDoc = await _db
        .collection('attendance_session')
        .doc(sessionId)
        .get();

    if (sessionDoc.exists) {
      final mapData = sessionDoc.data();
      final isActive = mapData?['isActive'] == true;

      if (isActive && _isSessionValid(sessionDoc)) {
        _showSnack("$sessionType session is already active");
        return;
      }

      if (!isActive && mapData?['endedAt'] != null) {
        _showSnack("$sessionType session already completed today");
        return;
      }
    }

    setState(() => isLoading = true);

    try {
      final now = DateTime.now();
      final expiresAt = now.add(SESSION_DURATION);

      print("📅 Creating session with expiresAt: $expiresAt");

      await _db.collection('attendance_session').doc(sessionId).set({
        'classId': classId,
        'date': today,
        'sessionType': sessionType,
        'isActive': true,
        'startedBy': user.uid,
        'startedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'endedAt': null,
        'endReason': null,
      });

      await _db.collection('attendance').doc(sessionId).set({
        'classId': classId,
        'date': today,
        'sessionType': sessionType,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnack(
        "✅ ${_capitalize(sessionType)} session started for 4 hours",
        success: true,
      );

      await _loadSessionStatus();
    } catch (e) {
      print("❌ Error starting session: $e");
      _showSnack("❌ Error starting session: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= STOP SESSION =================
  Future<void> _stopSession() async {
    if (classId == null) return _showSnack("Class not assigned");

    final today = _todayId();
    final sessionId = "${classId}_${today}_$sessionType";

    final sessionDoc = await _db
        .collection('attendance_session')
        .doc(sessionId)
        .get();

    if (!sessionDoc.exists) {
      _showSnack("❌ No $sessionType session found");
      return;
    }

    final mapData = sessionDoc.data();

    if (mapData?['isActive'] != true) {
      _showSnack("❌ $sessionType session is not active");
      return;
    }

    setState(() => isLoading = true);

    try {
      await _db.collection('attendance_session').doc(sessionId).update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
        'endReason': 'manual_stop',
      });

      _showSnack(
        "✅ ${_capitalize(sessionType)} session stopped",
        success: true,
      );

      if (sessionType == "afternoon") {
        _showSnack("📊 Calculating final attendance...", success: true);
        await Future.delayed(const Duration(seconds: 2));
        await _finalizeAttendanceAsync(classId!, today);
        _showSnack("✅ Attendance finalized!", success: true);
      } else {
        _showSnack(
          "ℹ️ Start afternoon session to complete attendance",
          success: true,
        );
      }

      await _loadSessionStatus();
    } catch (e) {
      _showSnack("❌ Error stopping session: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= FINALIZE ATTENDANCE =================
  Future<void> _finalizeAttendanceAsync(String classId, String today) async {
    try {
      print("📊 Starting attendance finalization for $classId on $today...");

      final finalDocId = '${classId}_$today';
      final finalRef = _db.collection('attendance_final').doc(finalDocId);

      // 1. Get All Students
      final studentsSnap = await _db
          .collection('student')
          .where('classId', isEqualTo: classId)
          .get();

      if (studentsSnap.docs.isEmpty) {
        print("⚠️ No students found for this class.");
        return;
      }

      // 2. Get Morning & Afternoon Attendance
      final results = await Future.wait([
        _db
            .collection('attendance')
            .doc('${classId}_${today}_morning')
            .collection('student')
            .get(),
        _db
            .collection('attendance')
            .doc('${classId}_${today}_afternoon')
            .collection('student')
            .get(),
        finalRef.collection('student').get(),
      ]);

      final morningSnap = results[0];
      final afternoonSnap = results[1];
      final existingFinal = results[2];

      final morningMap = {for (var d in morningSnap.docs) d.id: true};
      final afternoonMap = {for (var d in afternoonSnap.docs) d.id: true};

      final manualOverrides = {
        for (var d in existingFinal.docs)
          if ((d.data()['method'] ?? '') == 'manual_override') d.id: true,
      };

      WriteBatch batch = _db.batch();
      int processedCount = 0;
      int presentCount = 0;
      int halfDayCount = 0;
      int absentCount = 0;

      for (final stu in studentsSnap.docs) {
        final studentId = stu.id;

        if (manualOverrides.containsKey(studentId)) {
          final status = existingFinal.docs
              .firstWhere((d) => d.id == studentId)
              .data()['status'];
          if (status == 'present')
            presentCount++;
          else if (status == 'half-day')
            halfDayCount++;
          else
            absentCount++;
          continue;
        }

        final morningPresent = morningMap.containsKey(studentId);
        final afternoonPresent = afternoonMap.containsKey(studentId);

        String status;
        if (morningPresent && afternoonPresent) {
          status = 'present';
          presentCount++;
        } else if (morningPresent || afternoonPresent) {
          status = 'half-day';
          halfDayCount++;
        } else {
          status = 'absent';
          absentCount++;
        }

        batch.set(finalRef.collection('student').doc(studentId), {
          'studentId': studentId,
          'admissionNo': stu.data()['admissionNo'] ?? studentId,
          'name': stu.data()['name'] ?? 'Unknown',
          'status': status,
          'morningPresent': morningPresent,
          'afternoonPresent': afternoonPresent,
          'method': 'auto_calc',
          'computedAt': FieldValue.serverTimestamp(),
        });

        processedCount++;
        if (processedCount % 400 == 0) {
          await batch.commit();
          batch = _db.batch();
        }
      }

      if (processedCount % 400 != 0) await batch.commit();

      await finalRef.set({
        'classId': classId,
        'date': today,
        'totalStudents': studentsSnap.docs.length,
        'presentCount': presentCount,
        'halfDayCount': halfDayCount,
        'absentCount': absentCount,
        'status': 'finalized',
        'finalizedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print(
        "🎉 Finalization success! P:$presentCount H:$halfDayCount A:$absentCount",
      );
    } catch (e) {
      print("❌ Finalization CRITICAL error: $e");
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
        elevation: 0,
        iconTheme: IconThemeData(color: primaryBlue),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.refresh),
        //     onPressed: _loadSessionStatus,
        //     tooltip: "Refresh",
        //   ),
        // ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSessionStatus,
        color: primaryBlue,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.class_, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        className.isNotEmpty ? className : "Loading...",
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Attendance finalizes when afternoon stops",
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _card(
                _sessionRadio(
                  title: "Morning",
                  value: "morning",
                  isActive: isMorningActive,
                  isCompleted: isMorningCompleted,
                  timeLeft: morningTimeLeft,
                  studentsMarked: morningStudentsMarked,
                ),
              ),
              const SizedBox(height: 12),
              _card(
                _sessionRadio(
                  title: "Afternoon",
                  value: "afternoon",
                  isActive: isAfternoonActive,
                  isCompleted: isAfternoonCompleted,
                  timeLeft: afternoonTimeLeft,
                  studentsMarked: afternoonStudentsMarked,
                ),
              ),
              const SizedBox(height: 40),
              _btn(
                "START ATTENDANCE",
                _startSession,
                isDisabled:
                    (sessionType == "morning" &&
                        (isMorningActive || isMorningCompleted)) ||
                    (sessionType == "afternoon" &&
                        (isAfternoonActive || isAfternoonCompleted)),
              ),
              const SizedBox(height: 16),
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
      ),
    );
  }

  Widget _sessionRadio({
    required String title,
    required String value,
    required bool isActive,
    required String timeLeft,
    required String studentsMarked,
    bool isCompleted = false,
  }) {
    return RadioListTile<String>(
      value: value,
      groupValue: sessionType,
      activeColor: primaryBlue,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              if (isActive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "🟢 ACTIVE",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "✅ DONE",
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "🔴 INACTIVE",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  "Time: $timeLeft",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  "Marked: $studentsMarked",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ],
      ),
      onChanged: (v) => setState(() => sessionType = v!),
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

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

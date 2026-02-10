import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/attendance/attendance_finalize.dart';
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
  // ---------------- BASIC STATE ----------------
  String classId = "";
  String className = "";
  String sessionType = "morning";
  bool isLoading = false;

  bool isMorningActive = false;
  bool isAfternoonActive = false;
  bool isMorningCompleted = false;
  bool isAfternoonCompleted = false;

  String morningStudents = "0";
  String afternoonStudents = "0";
  String morningTime = "04:00:00";
  String afternoonTime = "04:00:00";

  DateTime? morningExpire;
  DateTime? afternoonExpire;

  Timer? displayTimer;

  final FirebaseFirestore db = FirebaseFirestore.instance;
  final AttendanceService attendanceService = AttendanceService();

  // ---------------- THEME COLORS ----------------
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color bgLight = const Color(0xFFF5F7FA);
  final Color textDark = const Color(0xFF263238);

  // ---------------- LIFECYCLE ----------------
  @override
  void initState() {
    super.initState();
    loadTeacher();
    _startTimer();
  }

  @override
  void dispose() {
    displayTimer?.cancel();
    super.dispose();
  }

  // ---------------- TIMER ----------------
  void _startTimer() {
    displayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateTimes();
    });
  }

  void _updateTimes() {
    setState(() {
      if (morningExpire != null) {
        morningTime = _formatTime(morningExpire!);
      }
      if (afternoonExpire != null) {
        afternoonTime = _formatTime(afternoonExpire!);
      }
    });
  }

  String _formatTime(DateTime expiry) {
    final diff = expiry.difference(DateTime.now());
    if (diff.isNegative) return "Expired";
    return "${diff.inHours.toString().padLeft(2, '0')}:"
        "${(diff.inMinutes % 60).toString().padLeft(2, '0')}:"
        "${(diff.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  String getToday() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  bool _isWeekend() {
    final d = DateTime.now();
    return d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
  }

  // ---------------- LOAD TEACHER ----------------
  Future<void> loadTeacher() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final q = await db
          .collection('teacher')
          .where('authUid', isEqualTo: user.uid)
          .get();

      if (q.docs.isNotEmpty) {
        final data = q.docs.first.data();
        final ids = data['classIds'] as List?;
        if (ids != null && ids.isNotEmpty) {
          setState(() => classId = ids.first.toString());
          await _loadClassName();
          await _loadSessionStatus();
        }
      }
    } catch (e) {
      debugPrint("Teacher load error: $e");
    }
  }

  Future<void> _loadClassName() async {
    final d = await db.collection('class').doc(classId).get();
    if (d.exists) {
      setState(() {
        className = d.data()?['name'] ?? d.data()?['className'] ?? classId;
      });
    }
  }

  // ---------------- SESSION STATUS ----------------
  Future<void> _loadSessionStatus() async {
    final today = getToday();

    final morningDoc = await db
        .collection('attendance_session')
        .doc('${classId}_${today}_morning')
        .get();

    final afternoonDoc = await db
        .collection('attendance_session')
        .doc('${classId}_${today}_afternoon')
        .get();

    final morningList = await db
        .collection('attendance')
        .doc('${classId}_${today}_morning')
        .collection('student')
        .get();

    final afternoonList = await db
        .collection('attendance')
        .doc('${classId}_${today}_afternoon')
        .collection('student')
        .get();

    if (!mounted) return;

    setState(() {
      isMorningActive = morningDoc.exists && morningDoc['isActive'] == true;
      isMorningCompleted = morningDoc.exists && morningDoc['isActive'] == false;
      morningExpire = morningDoc.exists && morningDoc['expiresAt'] != null
          ? (morningDoc['expiresAt'] as Timestamp).toDate()
          : null;

      isAfternoonActive =
          afternoonDoc.exists && afternoonDoc['isActive'] == true;
      isAfternoonCompleted =
          afternoonDoc.exists && afternoonDoc['isActive'] == false;
      afternoonExpire = afternoonDoc.exists && afternoonDoc['expiresAt'] != null
          ? (afternoonDoc['expiresAt'] as Timestamp).toDate()
          : null;

      morningStudents = morningList.docs.length.toString();
      afternoonStudents = afternoonList.docs.length.toString();
    });
  }

  // ---------------- START SESSION ----------------
  Future<void> startSession() async {
    if (classId.isEmpty) return;
    if (_isWeekend()) {
      _show("📅 Today is a holiday");
      return;
    }

    setState(() => isLoading = true);

    try {
      final today = getToday();
      final id = "${classId}_${today}_$sessionType";
      final expires = DateTime.now().add(const Duration(hours: 4));

      await db.collection('attendance_session').doc(id).set({
        'classId': classId,
        'date': today,
        'sessionType': sessionType,
        'isActive': true,
        'startedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expires),
      });

      await db.collection('attendance').doc(id).set({
        'created': true,
      }, SetOptions(merge: true));

      await _loadSessionStatus();
      _show("✅ $sessionType session started");
    } catch (e) {
      _show("❌ $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ---------------- STOP SESSION ----------------
  Future<void> stopSession() async {
    if (classId.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final today = getToday();
      final id = "${classId}_${today}_$sessionType";

      await db.collection('attendance_session').doc(id).update({
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
      });

      // ✅ FINALIZE ONLY VIA SERVICE
      if (sessionType == 'afternoon') {
        await attendanceService.finalizeDayAttendance(
          classId: classId,
          date: today,
          context: context,
          isAuto: false,
        );
      }

      await _loadSessionStatus();
      _show("✅ $sessionType session stopped");
    } catch (e) {
      _show("❌ $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ---------------- UI HELPERS ----------------
  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- UI BUILD ----------------
  @override
  Widget build(BuildContext context) {
    if (classId.isEmpty) {
      return Scaffold(
        backgroundColor: bgLight,
        body: Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- Class Header ---
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.class_, color: Colors.purple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      className.isNotEmpty ? className : "Loading Class...",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- Session Cards ---
            _buildSessionRadioCard(
              title: "Morning",
              value: "morning",
              isActive: isMorningActive,
              isCompleted: isMorningCompleted,
              timeLeft: morningTime,
              count: morningStudents,
            ),
            const SizedBox(height: 12),
            _buildSessionRadioCard(
              title: "Afternoon",
              value: "afternoon",
              isActive: isAfternoonActive,
              isCompleted: isAfternoonCompleted,
              timeLeft: afternoonTime,
              count: afternoonStudents,
            ),

            const SizedBox(height: 24),

            // ✅ ADDED: Live Attendance List (Only when active)
            if ((sessionType == "morning" && isMorningActive) ||
                (sessionType == "afternoon" && isAfternoonActive))
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: LiveFaceAttendanceMonitor(
                  // Key ensures the widget refreshes when session changes
                  key: ValueKey(sessionType),
                  classId: classId,
                  date: getToday(),
                  sessionType: sessionType,
                ),
              ),

            // --- Action Buttons ---
            if (sessionType == "morning" &&
                !isMorningActive &&
                !isMorningCompleted)
              _buildBtn("START MORNING", startSession, color: primaryBlue),

            if (sessionType == "morning" && isMorningActive)
              _buildBtn("STOP MORNING", stopSession, color: Colors.red),

            if (sessionType == "afternoon" &&
                !isAfternoonActive &&
                !isAfternoonCompleted)
              _buildBtn("START AFTERNOON", startSession, color: primaryBlue),

            if (sessionType == "afternoon" && isAfternoonActive)
              _buildBtn("STOP & FINALIZE", stopSession, color: Colors.red),

            // --- Completed Message ---
            if ((sessionType == "morning" && isMorningCompleted) ||
                (sessionType == "afternoon" && isAfternoonCompleted))
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "$sessionType session completed".toUpperCase(),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildSessionRadioCard({
    required String title,
    required String value,
    required bool isActive,
    required bool isCompleted,
    required String timeLeft,
    required String count,
  }) {
    bool isSelected = sessionType == value;

    return GestureDetector(
      onTap: () => setState(() => sessionType = value),
      child: Container(
        padding: const EdgeInsets.all(4), // For border width
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryBlue : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? primaryBlue : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  _buildStatusBadge(isActive, isCompleted),
                ],
              ),
              if (isActive || isCompleted) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoItem(Icons.timer_outlined, "Time Left", timeLeft),
                    _buildInfoItem(Icons.people_outline, "Marked", count),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive, bool isCompleted) {
    String text = "IDLE";
    Color color = Colors.grey;
    if (isActive) {
      text = "ACTIVE";
      color = Colors.green;
    } else if (isCompleted) {
      text = "DONE";
      color = primaryBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBtn(String text, VoidCallback onTap, {required Color color}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: isLoading ? null : onTap,
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  ✅ APPENDED: Live Face Attendance Monitor & Helper Classes
// ---------------------------------------------------------------------------

class LiveFaceAttendanceMonitor extends StatefulWidget {
  final String classId;
  final String date;
  final String sessionType;

  const LiveFaceAttendanceMonitor({
    super.key,
    required this.classId,
    required this.date,
    required this.sessionType,
  });

  @override
  State<LiveFaceAttendanceMonitor> createState() =>
      _LiveFaceAttendanceMonitorState();
}

class _LiveFaceAttendanceMonitorState extends State<LiveFaceAttendanceMonitor> {
  late Stream<QuerySnapshot> _attendanceStream;
  final Color primaryBlue = const Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    // 1. Initialize stream ONCE.
    final String sessionId =
        "${widget.classId}_${widget.date}_${widget.sessionType}";

    _attendanceStream = FirebaseFirestore.instance
        .collection('attendance')
        .doc(sessionId)
        .collection('student')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final String sessionId =
        "${widget.classId}_${widget.date}_${widget.sessionType}";

    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        var docs = snapshot.data!.docs;

        // 2. Local Sort (Newest first)
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          Timestamp? tA = dataA['timestamp'] as Timestamp?;
          Timestamp? tB = dataB['timestamp'] as Timestamp?;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        int count = docs.length;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: ExpansionTile(
            shape: const Border(),
            initiallyExpanded: true,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            title: const Text(
              "Live Face Scans",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              "Real-time verification",
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            children: [
              if (count == 0)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.face_retouching_off,
                        size: 40,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "No students verified yet.",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: docs.length,
                    separatorBuilder: (ctx, i) => Divider(
                      height: 1,
                      color: Colors.grey.withOpacity(0.1),
                      indent: 70,
                    ),
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      return _StudentListTile(
                        docId: docs[index].id,
                        data: data,
                        sessionId: sessionId,
                        onRemove: _removeStudent,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _removeStudent(
    String sessionId,
    String docId,
    String name,
    BuildContext context,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Unmark Student?"),
        content: Text("Remove $name from this session?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('attendance')
                  .doc(sessionId)
                  .collection('student')
                  .doc(docId)
                  .delete();
            },
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StudentListTile extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String sessionId;
  final Function(String, String, String, BuildContext) onRemove;

  const _StudentListTile({
    required this.docId,
    required this.data,
    required this.sessionId,
    required this.onRemove,
  });

  @override
  State<_StudentListTile> createState() => _StudentListTileState();
}

class _StudentListTileState extends State<_StudentListTile> {
  String _displayName = "Loading...";
  bool _isLoadingName = true;

  @override
  void initState() {
    super.initState();
    _resolveName();
  }

  Future<void> _resolveName() async {
    // 1. Check if name is already in the attendance doc
    String? cachedName = widget.data['name'];
    if (cachedName != null && cachedName != 'Unknown') {
      if (mounted) {
        setState(() {
          _displayName = cachedName;
          _isLoadingName = false;
        });
      }
      return;
    }

    // 2. Fetch from student collection
    String admissionNo = widget.data['admissionNo'] ?? widget.docId;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('student')
          .where('admissionNo', isEqualTo: admissionNo)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final studentData = snap.docs.first.data();
        if (mounted) {
          setState(() {
            _displayName = studentData['name'] ?? "Unknown ($admissionNo)";
            _isLoadingName = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _displayName = "Unknown ($admissionNo)";
            _isLoadingName = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _displayName = "Error ($admissionNo)";
          _isLoadingName = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String admissionNo = widget.data['admissionNo'] ?? widget.docId;

    String timeStr = "--:--";
    if (widget.data['timestamp'] != null &&
        widget.data['timestamp'] is Timestamp) {
      DateTime dt = (widget.data['timestamp'] as Timestamp).toDate();
      timeStr =
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: Colors.grey[100],
        child: const Icon(Icons.person, color: Colors.blueGrey, size: 20),
      ),
      title: _isLoadingName
          ? const SizedBox(
              height: 14,
              width: 100,
              child: LinearProgressIndicator(minHeight: 2),
            )
          : Text(
              _displayName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
      subtitle: Text(
        "$admissionNo • $timeStr",
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
        tooltip: "Unmark Student",
        onPressed: () => widget.onRemove(
          widget.sessionId,
          widget.docId,
          _displayName,
          context,
        ),
      ),
    );
  }
}

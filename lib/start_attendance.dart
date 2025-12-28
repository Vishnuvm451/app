import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StartAttendancePage extends StatefulWidget {
  const StartAttendancePage({super.key});

  @override
  State<StartAttendancePage> createState() => _StartAttendancePageState();
}

class _StartAttendancePageState extends State<StartAttendancePage> {
  String? selectedClassId;
  String sessionType = 'morning'; // morning | afternoon
  int selectedMinutes = 10;
  bool isLoading = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<int> durations = [5, 10, 15, 20, 30];
  final List<String> sessionTypes = ['morning', 'afternoon'];

  // ===================================================
  // START ATTENDANCE
  // ===================================================
  Future<void> _startAttendance() async {
    if (selectedClassId == null) {
      _showSnack("Select a class");
      return;
    }

    final teacher = FirebaseAuth.instance.currentUser;
    if (teacher == null) return;

    final today = _todayId();
    final sessionId = '${selectedClassId}_${today}_$sessionType';

    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(minutes: selectedMinutes));

    try {
      setState(() => isLoading = true);

      final ref = _db.collection('attendance_sessions').doc(sessionId);

      // Prevent duplicate
      if ((await ref.get()).exists) {
        _showSnack("Attendance already started for ${_prettySession()}");
        return;
      }

      // ---------- CREATE SESSION ----------
      await ref.set({
        'classId': selectedClassId,
        'date': today,
        'sessionType': sessionType,
        'startedBy': teacher.uid,
        'isActive': true,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': selectedMinutes,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showSnack("${_prettySession()} attendance started", success: true);

      Navigator.pop(context);
    } catch (e) {
      _showSnack("Failed to start attendance");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ===================================================
  // FINAL DAY ATTENDANCE (MORNING + AFTERNOON)
  // ===================================================
  Future<void> calculateFinalAttendance({
    required String classId,
    required String date,
  }) async {
    final morningId = '${classId}_${date}_morning';
    final afternoonId = '${classId}_${date}_afternoon';

    final morningSnap = await _db
        .collection('attendance')
        .doc(morningId)
        .collection('students')
        .get();

    final afternoonSnap = await _db
        .collection('attendance')
        .doc(afternoonId)
        .collection('students')
        .get();

    // ❗ Both sessions must exist
    if (morningSnap.docs.isEmpty || afternoonSnap.docs.isEmpty) return;

    final Map<String, String> morning = {
      for (var d in morningSnap.docs) d.id: d['status'],
    };

    final Map<String, String> afternoon = {
      for (var d in afternoonSnap.docs) d.id: d['status'],
    };

    final batch = _db.batch();
    final finalRef = _db.collection('attendance_final').doc('${classId}_$date');

    for (final studentId in morning.keys) {
      final m = morning[studentId];
      final a = afternoon[studentId];

      String finalStatus;
      if (m == 'present' && a == 'present') {
        finalStatus = 'present';
      } else if (m == 'absent' && a == 'absent') {
        finalStatus = 'absent';
      } else {
        finalStatus = 'half-day';
      }

      batch.set(finalRef.collection('students').doc(studentId), {
        'studentId': studentId,
        'status': finalStatus,
        'date': date,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  // ===================================================
  // UI
  // ===================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Start Attendance"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _classDropdown(),
            const SizedBox(height: 16),
            _sessionTypeDropdown(),
            const SizedBox(height: 16),
            _durationDropdown(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : _startAttendance,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "START ATTENDANCE",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================
  // CLASS DROPDOWN (FIXED)
  // ===================================================
  Widget _classDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('classes').orderBy('name').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const LinearProgressIndicator();
        }

        return DropdownButtonFormField<String>(
          hint: const Text("Select Class"),
          value: selectedClassId,
          items: snap.data!.docs.map((doc) {
            return DropdownMenuItem(value: doc.id, child: Text(doc['name']));
          }).toList(),
          onChanged: (v) => setState(() => selectedClassId = v),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.class_),
          ),
        );
      },
    );
  }

  // ===================================================
  // SESSION TYPE
  // ===================================================
  Widget _sessionTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: sessionType,
      items: sessionTypes.map((s) {
        return DropdownMenuItem(
          value: s,
          child: Text(s == 'morning' ? 'Morning Session' : 'Afternoon Session'),
        );
      }).toList(),
      onChanged: (v) => setState(() => sessionType = v!),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.wb_sunny),
        labelText: "Session Type",
      ),
    );
  }

  // ===================================================
  // DURATION
  // ===================================================
  Widget _durationDropdown() {
    return DropdownButtonFormField<int>(
      value: selectedMinutes,
      items: durations
          .map((m) => DropdownMenuItem(value: m, child: Text("$m minutes")))
          .toList(),
      onChanged: (v) => setState(() => selectedMinutes = v!),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.timer),
        labelText: "Attendance Duration",
      ),
    );
  }

  // ===================================================
  // HELPERS
  // ===================================================
  String _todayId() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _prettySession() => sessionType == 'morning' ? 'Morning' : 'Afternoon';

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

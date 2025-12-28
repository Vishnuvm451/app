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
  int selectedMinutes = 10;
  bool isLoading = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<int> durations = [5, 10, 15, 20, 30];

  // ===================================================
  // START ATTENDANCE WITH TIME WINDOW
  // ===================================================
  Future<void> _startAttendance() async {
    if (selectedClassId == null) {
      _showSnack("Select a class");
      return;
    }

    final teacherId = FirebaseAuth.instance.currentUser!.uid;
    final today = _todayId();
    final sessionId = '${selectedClassId}_$today';

    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(minutes: selectedMinutes));

    try {
      setState(() => isLoading = true);

      final ref = _db.collection('attendance_sessions').doc(sessionId);

      final existing = await ref.get();
      if (existing.exists) {
        _showSnack("Attendance already started today");
        return;
      }

      await ref.set({
        'classId': selectedClassId,
        'date': today,
        'startedBy': teacherId,
        'isActive': true,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'durationMinutes': selectedMinutes,
        'startedAt': FieldValue.serverTimestamp(),
      });

      _showSnack(
        "Attendance started for $selectedMinutes minutes",
        success: true,
      );

      Navigator.pop(context);
    } catch (_) {
      _showSnack("Failed to start attendance");
    } finally {
      setState(() => isLoading = false);
    }
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================
  // CLASS DROPDOWN
  // ===================================================
  Widget _classDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('classes').snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }

        return DropdownButtonFormField<String>(
          hint: const Text("Select Class"),
          value: selectedClassId,
          items: snapshot.data!.docs.map((doc) {
            return DropdownMenuItem(value: doc.id, child: Text(doc['name']));
          }).toList(),
          onChanged: (val) => setState(() => selectedClassId = val),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.class_),
          ),
        );
      },
    );
  }

  // ===================================================
  // DURATION DROPDOWN
  // ===================================================
  Widget _durationDropdown() {
    return DropdownButtonFormField<int>(
      value: selectedMinutes,
      items: durations
          .map((m) => DropdownMenuItem(value: m, child: Text("$m minutes")))
          .toList(),
      onChanged: (val) => setState(() => selectedMinutes = val!),
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
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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

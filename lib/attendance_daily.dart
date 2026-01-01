import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ManualAttendancePage extends StatefulWidget {
  final String classId;

  const ManualAttendancePage({super.key, required this.classId});

  @override
  State<ManualAttendancePage> createState() => _ManualAttendancePageState();
}

class _ManualAttendancePageState extends State<ManualAttendancePage> {
  // ---------------- STATE ----------------
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool isSaving = false;

  /// studentId -> status
  /// present | half-day | absent
  final Map<String, String> attendanceData = {};

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===================================================
  // INIT — TEACHER ONLY ACCESS
  // ===================================================
  @override
  void initState() {
    super.initState();
    _checkTeacherAccess();
  }

  Future<void> _checkTeacherAccess() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _denyAccess();
      return;
    }

    final roleSnap = await _db.collection('users').doc(user.uid).get();

    if (!roleSnap.exists || roleSnap['role'] != 'teacher') {
      _denyAccess();
    }
  }

  void _denyAccess() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Access denied: Teachers only"),
        backgroundColor: Colors.red,
      ),
    );

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      Navigator.pop(context);
    });
  }

  // ===================================================
  // UI
  // ===================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manual Attendance"), centerTitle: true),
      body: Column(
        children: [
          const SizedBox(height: 12),

          // ---------------- DATE ----------------
          Text("Date: $selectedDate", style: const TextStyle(fontSize: 16)),

          const SizedBox(height: 6),

          ElevatedButton(onPressed: _pickDate, child: const Text("Pick Date")),

          const SizedBox(height: 12),

          // ---------------- STUDENTS ----------------
          Expanded(child: _studentsList()),

          // ---------------- SAVE ----------------
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveAttendance,
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SAVE ATTENDANCE",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // STUDENTS LIST
  // ===================================================
  Widget _studentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('student')
          .where('classId', isEqualTo: widget.classId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = snapshot.data!.docs;

        if (students.isEmpty) {
          return const Center(child: Text("No students found"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final stu = students[index];
            final stuId = stu.id;

            // ✅ DEFAULT = PRESENT
            final status = attendanceData[stuId] ?? 'present';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(stu['name'] ?? 'Student'),
                subtitle: Text("Admission No: ${stu['admissionNo'] ?? ''}"),
                trailing: DropdownButton<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'present', child: Text("Present")),
                    DropdownMenuItem(
                      value: 'half-day',
                      child: Text("Half Day"),
                    ),
                    DropdownMenuItem(value: 'absent', child: Text("Absent")),
                  ],
                  onChanged: (val) {
                    setState(() {
                      attendanceData[stuId] = val!;
                    });
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===================================================
  // DATE PICKER
  // ===================================================
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2026),
    );

    if (picked != null) {
      setState(() {
        selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // ===================================================
  // SAVE ATTENDANCE (MANUAL EDIT / FUTURE EDIT)
  // ===================================================
  Future<void> _saveAttendance() async {
    if (attendanceData.isEmpty) {
      _showSnack("No attendance marked");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 🔒 DOUBLE CHECK ROLE
    final roleSnap = await _db.collection('users').doc(user.uid).get();

    if (!roleSnap.exists || roleSnap['role'] != 'teacher') {
      _showSnack("Unauthorized action");
      return;
    }

    try {
      setState(() => isSaving = true);

      final sessionId = '${widget.classId}_$selectedDate';
      final batch = _db.batch();

      // Ensure session exists / update
      final sessionRef = _db.collection('attendance_session').doc(sessionId);

      batch.set(sessionRef, {
        'classId': widget.classId,
        'date': selectedDate,
        'startedBy': user.uid,
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save student attendance
      attendanceData.forEach((studentId, status) {
        final ref = _db
            .collection('attendance')
            .doc(sessionId)
            .collection('student')
            .doc(studentId);

        batch.set(ref, {
          'studentId': studentId,
          'status': status,
          'method': 'manual',
          'markedBy': user.uid,
          'markedAt': FieldValue.serverTimestamp(),
        });
      });

      await batch.commit();

      _showSnack("Attendance saved successfully", success: true);
    } catch (e) {
      _showSnack("Failed to save attendance");
    } finally {
      setState(() => isSaving = false);
    }
  }

  // ===================================================
  // SNACK
  // ===================================================
  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

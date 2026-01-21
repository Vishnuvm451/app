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
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool isSaving = false;

  final Map<String, String> attendanceData = {};

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Color primaryBlue = const Color(0xFF2196F3);

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

    try {
      final snap = await _db.collection('users').doc(user.uid).get();
      final data = snap.data();

      if (data == null || data['role'] != 'teacher') {
        _denyAccess();
      }
    } catch (_) {
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
      if (mounted) Navigator.pop(context);
    });
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Manual Attendance",
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
      body: Column(
        children: [
          _datePickerHeader(),
          Expanded(child: _studentsList()),
          _saveFooter(),
        ],
      ),
    );
  }

  // ---------------- DATE PICKER ----------------
  Widget _datePickerHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Selected Date",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                selectedDate,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month),
            label: const Text("Change"),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue.withOpacity(0.1),
              foregroundColor: primaryBlue,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- STUDENT LIST ----------------
  Widget _studentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('student')
          .where('classId', isEqualTo: widget.classId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No students found"));
        }

        final students = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: students.length,
          itemBuilder: (_, index) {
            final doc = students[index];
            final stuId = doc.id;
            final data = doc.data() as Map<String, dynamic>;

            final status = attendanceData[stuId] ?? 'present';
            final statusColor = _statusColor(status);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.15),
                  child: Text(
                    (data['name'] ?? 'S')[0].toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  data['name'] ?? 'Student',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("ID: ${data['admissionNo'] ?? '-'}"),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: status,
                      dropdownColor: Colors.white,
                      icon: Icon(Icons.arrow_drop_down, color: statusColor),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'present',
                          child: Text("Present"),
                        ),
                        DropdownMenuItem(
                          value: 'half-day',
                          child: Text("Half Day"),
                        ),
                        DropdownMenuItem(
                          value: 'absent',
                          child: Text("Absent"),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => attendanceData[stuId] = val);
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- SAVE ----------------
  Future<void> _saveAttendance() async {
    final parsedDate = DateFormat('yyyy-MM-dd').parse(selectedDate);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    if (parsedDate.isAfter(normalizedToday)) {
      _showSnack("Cannot mark attendance for future dates");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    try {
      final studentsSnap = await _db
          .collection('student')
          .where('classId', isEqualTo: widget.classId)
          .get();

      final finalDocId = '${widget.classId}_$selectedDate';
      final finalRef = _db.collection('attendance_final').doc(finalDocId);

      final batch = _db.batch();

      batch.set(finalRef, {
        'classId': widget.classId,
        'date': Timestamp.fromDate(parsedDate),
        'lastUpdatedBy': user.uid,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final stu in studentsSnap.docs) {
        final stuId = stu.id;
        final status = attendanceData[stuId] ?? 'present';

        batch.set(finalRef.collection('student').doc(stuId), {
          'studentId': stuId,
          'status': status,
          'method': 'manual_override',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      _showSnack("Attendance saved successfully", success: true);
    } catch (_) {
      _showSnack("Failed to save attendance");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Widget _saveFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: isSaving ? null : _saveAttendance,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  "FINALIZE ATTENDANCE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'present':
        return Colors.green;
      case 'half-day':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

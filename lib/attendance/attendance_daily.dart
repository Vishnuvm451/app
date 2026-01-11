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

  // Theme Color
  final Color primaryBlue = const Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _checkTeacherAccess();
    print(
      "DEBUG: ManualAttendancePage initialized for Class ID: ${widget.classId}",
    );
  }

  // ===================================================
  // INIT — TEACHER ONLY ACCESS
  // ===================================================
  Future<void> _checkTeacherAccess() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _denyAccess();
      return;
    }

    try {
      final roleSnap = await _db.collection('users').doc(user.uid).get();
      if (!roleSnap.exists || roleSnap['role'] != 'teacher') {
        _denyAccess();
      }
    } catch (e) {
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
      backgroundColor: const Color(0xFFF5F7FA), // Modern Background
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
          _datePickerHeader(), // ✅ Fixed Date Picker
          Expanded(child: _studentsList()), // ✅ Fixed Loading Logic
          _saveFooter(),
        ],
      ),
    );
  }

  // ===================================================
  // DATE PICKER HEADER
  // ===================================================
  Widget _datePickerHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Selected Date",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                selectedDate,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _pickDate,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue.withOpacity(0.1),
              foregroundColor: primaryBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.calendar_month_rounded),
            label: const Text("Change"),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // STUDENTS LIST (FIXED)
  // ===================================================
  Widget _studentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('student')
          .where('classId', isEqualTo: widget.classId)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. Show Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Handle Error
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        // 3. Handle Empty State (Fixes "Always Loading")
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_off_outlined,
                  size: 60,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 10),
                Text(
                  "No records found",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
                const SizedBox(height: 5),
                Text(
                  "Class ID: ${widget.classId}",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          );
        }

        final students = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final stu = students[index];
            final stuId = stu.id;

            // Default Status = Present
            final status = attendanceData[stuId] ?? 'present';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: primaryBlue.withOpacity(0.1),
                  child: Text(
                    (stu['name'] ?? 'S')[0].toUpperCase(),
                    style: TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  stu['name'] ?? 'Student',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("ID: ${stu['admissionNo'] ?? '-'}"),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: status,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: _getStatusColor(status),
                      ),
                      style: TextStyle(
                        color: _getStatusColor(status),
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
                        setState(() {
                          attendanceData[stuId] = val!;
                        });
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

  Color _getStatusColor(String status) {
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

  // ===================================================
  // SAVE FOOTER
  // ===================================================
  Widget _saveFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
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
            elevation: 4,
            shadowColor: primaryBlue.withOpacity(0.4),
          ),
          child: isSaving
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : const Text(
                  "SAVE ATTENDANCE",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
        ),
      ),
    );
  }

  // ===================================================
  // DATE PICKER (FIXED)
  // ===================================================
  Future<void> _pickDate() async {
    DateTime currentSelection;
    try {
      currentSelection = DateFormat('yyyy-MM-dd').parse(selectedDate);
    } catch (_) {
      currentSelection = DateTime.now();
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: currentSelection,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(), // ✅ FIX: Extended to 2030
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryBlue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryBlue),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  // ===================================================
  // SAVE ATTENDANCE
  // ===================================================
  Future<void> _saveAttendance() async {
    final dateObj = DateFormat('yyyy-MM-dd').parse(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (dateObj.isAfter(today)) {
      _showSnack("Cannot mark attendance for future dates");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final roleSnap = await _db.collection('users').doc(user.uid).get();

    if (!roleSnap.exists || roleSnap['role'] != 'teacher') {
      _showSnack("Unauthorized action");
      return;
    }

    try {
      setState(() => isSaving = true);

      // Fetch ALL students to save for everyone
      final studentsSnap = await _db
          .collection('student')
          .where('classId', isEqualTo: widget.classId)
          .get();

      if (studentsSnap.docs.isEmpty) {
        _showSnack("No students to save");
        return;
      }

      final sessionId = '${widget.classId}_$selectedDate';
      final batch = _db.batch();

      // Ensure session exists
      final sessionRef = _db.collection('attendance_session').doc(sessionId);

      batch.set(sessionRef, {
        'classId': widget.classId,
        'date': selectedDate,
        'startedBy': user.uid,
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save student attendance
      for (var stu in studentsSnap.docs) {
        final stuId = stu.id;
        // Default to 'present' if not explicitly changed
        final status = attendanceData[stuId] ?? 'present';

        final ref = _db
            .collection('attendance')
            .doc(sessionId)
            .collection('student')
            .doc(stuId);

        batch.set(ref, {
          'studentId': stuId,
          'status': status,
          'method': 'manual',
          'markedBy': user.uid,
          'markedAt': FieldValue.serverTimestamp(),
        });
      }

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

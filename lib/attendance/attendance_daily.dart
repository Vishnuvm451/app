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
  // STUDENTS LIST (FIXED & DEBUGGED)
  // ===================================================
  Widget _studentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('student')
          .where('classId', isEqualTo: widget.classId)
          // .orderBy('name') // 🔴 UNCOMMENT THIS LATER (Requires Index)
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

        // 3. Handle Empty State (With Debug Info)
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
                const SizedBox(height: 10),
                // 🔍 DEBUG HELP: Shows what ID it is searching for
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.red.shade50,
                  child: Text(
                    "Searching for Class ID:\n'${widget.classId}'",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  "FINALIZE ATTENDANCE",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  // ===================================================
  // DATE PICKER (FIXED: DISABLE FUTURE DATES)
  // ===================================================
  Future<void> _pickDate() async {
    DateTime currentSelection;
    try {
      currentSelection = DateFormat('yyyy-MM-dd').parse(selectedDate);
    } catch (_) {
      currentSelection = DateTime.now();
    }

    // Limit selection to Today
    final now = DateTime.now();

    // Ensure initial date is not in the future
    if (currentSelection.isAfter(now)) {
      currentSelection = now;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: currentSelection,
      firstDate: DateTime(2020),
      lastDate: now, // ✅ RESTRICT: Max date is Today
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
  // SAVE ATTENDANCE (FIXED & CORRECTED)
  // ===================================================
  Future<void> _saveAttendance() async {
    // 1. ✅ FIX #1: Parse and normalize date to UTC
    final dateObj = DateFormat('yyyy-MM-dd').parse(selectedDate);
    // final utcDate = DateTime.utc(dateObj.year, dateObj.month, dateObj.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (dateObj.isAfter(today)) {
      _showSnack("Cannot mark attendance for future dates");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    try {
      // 2. Fetch ALL students
      final studentsSnap = await _db
          .collection('student')
          .where('classId', isEqualTo: widget.classId)
          .get();

      if (studentsSnap.docs.isEmpty) {
        _showSnack("No students to save");
        return;
      }

      // ✅ FIX #2: Check if finalization already ran for this date
      final finalDocId = '${widget.classId}_$selectedDate';
      final finalDocSnap = await _db
          .collection('attendance_final')
          .doc(finalDocId)
          .get();

      if (finalDocSnap.exists && finalDocSnap['finalizedAt'] != null) {
        _showSnack(
          "⚠️ Attendance already finalized for this date. Manual changes may be overwritten if auto-finalization runs again.",
          success: false,
        );
        // Continue anyway, but inform user
      }

      // ✅ FIX #3: Check for unmarked students
      final unmatchedStudents = <String>[];
      for (var stu in studentsSnap.docs) {
        final stuId = stu.id;
        if (!attendanceData.containsKey(stuId)) {
          unmatchedStudents.add(stu['name'] ?? stuId);
        }
      }

      if (unmatchedStudents.isNotEmpty) {
        print(
          "⚠️ ${unmatchedStudents.length} unmarked students will default to Present",
        );
      }

      // ✅ FIX #4: Handle batch limit (max 500 writes)
      const int batchLimit = 250; // 250 students = 500 writes (2 per student)
      int batchCount = 0;
      var batch = _db.batch();

      // Create/update final doc (counts as 1 write)
      final finalRef = _db.collection('attendance_final').doc(finalDocId);
      batch.set(finalRef, {
        'classId': widget.classId,
        'date': Timestamp.fromDate(dateObj), // IMPORTANT: Save as Timestamp
        'lastUpdatedBy': user.uid,
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'method': 'manual_override',
      }, SetOptions(merge: true));
      batchCount++;

      // ✅ FIX #5: Save to CORRECT path - attendance_final/{classId_date}/student/{stuId}
      for (var stu in studentsSnap.docs) {
        // Create new batch if limit nearly reached
        if (batchCount >= batchLimit - 5) {
          await batch.commit();
          batch = _db.batch();
          batchCount = 0;
          print("Batch committed. Continuing with next batch...");
        }

        final stuId = stu.id;
        final status = attendanceData[stuId] ?? 'present';

        // ✅ CORRECT PATH: attendance_final/{classId_date}/student/{stuId}
        final studentRecordRef = _db
            .collection('attendance_final')
            .doc(finalDocId)
            .collection('student')
            .doc(stuId);

        batch.set(studentRecordRef, {
          'studentId': stuId,
          'status': status, // 'present', 'half-day', 'absent'
          'method': 'manual_override',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        batchCount++;
      }

      // Commit remaining writes
      if (batchCount > 0) {
        await batch.commit();
        print("Final batch committed");
      }

      // ✅ FIX #6: Show confirmation with count
      _showSnack(
        "✅ Updated attendance for ${studentsSnap.docs.length} students",
        success: true,
      );
    } catch (e) {
      print("Save error: $e");
      _showSnack("Failed to save attendance: $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
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

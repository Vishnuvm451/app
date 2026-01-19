import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyAttendanceSummaryPage extends StatefulWidget {
  const MonthlyAttendanceSummaryPage({super.key});

  @override
  State<MonthlyAttendanceSummaryPage> createState() =>
      _MonthlyAttendanceSummaryPageState();
}

class _MonthlyAttendanceSummaryPageState
    extends State<MonthlyAttendanceSummaryPage> {
  bool isLoading = true;

  int present = 0;
  int halfDay = 0;
  int absent = 0;
  int totalDays = 0;

  DateTime selectedMonth = DateTime.now();
  String? classId;
  String? admissionNo; // Added to store Admission Number
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMonthlySummary();
  }

  // --------------------------------------------------
  // LOAD MONTHLY SUMMARY
  // --------------------------------------------------
  Future<void> _loadMonthlySummary() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final auth = context.read<AppAuthProvider>();
      final user = auth.user;

      if (user == null) throw Exception("User not logged in");

      // 1. GET CLASS ID & ADMISSION NUMBER (If not already loaded)
      if (classId == null || admissionNo == null) {
        final studentQuery = await FirebaseFirestore.instance
            .collection('student')
            .where('authUid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (studentQuery.docs.isEmpty) {
          throw Exception("Student profile not found");
        }

        final studentDoc = studentQuery.docs.first;
        final studentData = studentDoc.data();

        classId = studentData['classId'];
        admissionNo = studentDoc.id; // Admission Number (e.g., 50806)

        if (classId == null || classId!.isEmpty) {
          throw Exception("Class ID not found");
        }
      }

      // 2. GENERATE QUERY FOR THE MONTH
      final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

      // Start/End Doc IDs for Range Query (e.g., "CSE_A_2024-01-01")
      final startDocId =
          '${classId}_${DateFormat('yyyy-MM-dd').format(firstDay)}';
      // Add 1 day to end range to ensure the last day is included
      final endDocId =
          '${classId}_${DateFormat('yyyy-MM-dd').format(lastDay.add(const Duration(days: 1)))}';

      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance_final')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThan: endDocId)
          .get();

      // 3. COUNT ATTENDANCE
      int presentCount = 0;
      int halfDayCount = 0;
      int absentCount = 0;
      int totalDaysCount = 0;

      for (var doc in attendanceSnapshot.docs) {
        // Use 'admissionNo' to check the specific student's status
        final studentStatusDoc = await doc.reference
            .collection('student')
            .doc(admissionNo)
            .get();

        if (studentStatusDoc.exists) {
          totalDaysCount++;
          final status = studentStatusDoc.data()?['status'] ?? '';

          if (status == 'present') {
            presentCount++;
          } else if (status == 'half-day' || status == 'halfday') {
            halfDayCount++;
          } else if (status == 'absent') {
            absentCount++;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        present = presentCount;
        halfDay = halfDayCount;
        absent = absentCount;
        totalDays = totalDaysCount;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading monthly summary: $e");
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
        isLoading = false;
      });
    }
  }

  // --------------------------------------------------
  // MONTH PICKER
  // --------------------------------------------------
  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2022),
      // ✅ This limits the calendar to Today's date (Cannot pick future)
      lastDate: DateTime.now(),
      helpText: "Select Month",
    );

    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadMonthlySummary();
    }
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final percentage = totalDays == 0
        ? 0.0
        : ((present + (halfDay * 0.5)) / totalDays) * 100;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light background
      appBar: AppBar(
        title: const Text(
          "Attendance Summary",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(errorMessage!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: _loadMonthlySummary,
                    child: const Text("Retry"),
                  ),
                ],
              ),
            )
          : totalDays == 0
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ FIXED: Changed 'calendar_off' to 'event_busy'
                  Icon(Icons.event_busy, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    "No records for ${DateFormat('MMMM').format(selectedMonth)}",
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _pickMonth,
                    icon: const Icon(Icons.calendar_month),
                    label: const Text("Change Month"),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _monthSelector(),
                  const SizedBox(height: 20),

                  // Percentage Card
                  _percentageCard(percentage),
                  const SizedBox(height: 20),

                  // Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          "Present",
                          present,
                          Colors.green,
                          Icons.check_circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          "Absent",
                          absent,
                          Colors.red,
                          Icons.cancel,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          "Half Day",
                          halfDay,
                          Colors.orange,
                          Icons.access_time_filled,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statCard(
                          "Total Days",
                          totalDays,
                          Colors.blue,
                          Icons.calendar_today,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // --------------------------------------------------
  // WIDGETS
  // --------------------------------------------------
  Widget _monthSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.calendar_month, color: Colors.blue),
        title: Text(
          DateFormat('MMMM yyyy').format(selectedMonth),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        trailing: const Icon(Icons.arrow_drop_down),
        onTap: _pickMonth,
      ),
    );
  }

  Widget _percentageCard(double percentage) {
    Color color = percentage >= 75
        ? Colors.green
        : (percentage >= 50 ? Colors.orange : Colors.red);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Attendance Score",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade100,
                    color: color,
                  ),
                ),
                Text(
                  "${percentage.toStringAsFixed(1)}%",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, int value, Color color, IconData icon) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

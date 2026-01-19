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
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMonthlySummary();
  }

  // --------------------------------------------------
  // LOAD MONTHLY SUMMARY (OPTIMIZED)
  // --------------------------------------------------
  Future<void> _loadMonthlySummary() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final auth = context.read<AppAuthProvider>();
      final user = auth.user;

      if (user == null) {
        throw Exception("User not logged in");
      }

      // Load student data if classId is not cached
      if (classId == null) {
        final studentQuery = await FirebaseFirestore.instance
            .collection('student')
            .where('authUid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (studentQuery.docs.isEmpty) {
          throw Exception("Student profile not found");
        }

        final studentData = studentQuery.docs.first.data();
        classId = studentData['classId'];

        if (classId == null || classId!.isEmpty) {
          throw Exception("Class ID not found");
        }
      }

      // Generate date range for the month
      final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

      // Reset counters
      int presentCount = 0;
      int halfDayCount = 0;
      int absentCount = 0;
      int totalDaysCount = 0;

      // ✅ OPTIMIZED: Fetch all attendance records for the month in ONE query
      final startDocId = '${classId}_${DateFormat('yyyy-MM-dd').format(firstDay)}';
      final endDocId = '${classId}_${DateFormat('yyyy-MM-dd').format(lastDay.add(const Duration(days: 1)))}';

      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance_final')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThan: endDocId)
          .get();

      // Process each attendance document
      for (var doc in attendanceSnapshot.docs) {
        // Check if student exists in this attendance document
        final studentDoc = await doc.reference
            .collection('student')
            .doc(user.uid)
            .get();

        if (studentDoc.exists) {
          totalDaysCount++;
          final status = studentDoc.data()?['status'] ?? '';

          if (status == 'present') {
            presentCount++;
          } else if (status == 'halfday') {
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
      appBar: AppBar(
        title: const Text("Attendance Summary"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMessage = null;
                            });
                            _loadMonthlySummary();
                          },
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : totalDays == 0
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 60,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No attendance records found",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "for ${DateFormat('MMMM yyyy').format(selectedMonth)}",
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _monthSelector(),
                          const SizedBox(height: 20),

                          _summaryTile("Total Days", totalDays),
                          _summaryTile("Present", present, Colors.green),
                          _summaryTile("Half Day", halfDay, Colors.orange),
                          _summaryTile("Absent", absent, Colors.red),

                          const SizedBox(height: 20),

                          const Text(
                            "Attendance Chart",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          _attendanceBar(
                            label: "Present",
                            value: present,
                            total: totalDays,
                            color: Colors.green,
                          ),
                          _attendanceBar(
                            label: "Half Day",
                            value: halfDay,
                            total: totalDays,
                            color: Colors.orange,
                          ),
                          _attendanceBar(
                            label: "Absent",
                            value: absent,
                            total: totalDays,
                            color: Colors.red,
                          ),

                          const SizedBox(height: 24),

                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  "Attendance Percentage",
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "${percentage.toStringAsFixed(1)} %",
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: percentage >= 75
                                        ? Colors.green
                                        : percentage >= 50
                                            ? Colors.orange
                                            : Colors.red,
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

  // --------------------------------------------------
  // WIDGETS
  // --------------------------------------------------
  Widget _monthSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMMM yyyy').format(selectedMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _pickMonth,
              icon: const Icon(Icons.edit_calendar, size: 18),
              label: const Text("Change"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String title, int value, [Color? color]) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      child: ListTile(
        leading: Icon(
          _getIconForTitle(title),
          color: color ?? Colors.blue,
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        trailing: Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.blue,
          ),
        ),
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title) {
      case "Total Days":
        return Icons.calendar_today;
      case "Present":
        return Icons.check_circle;
      case "Half Day":
        return Icons.access_time;
      case "Absent":
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Widget _attendanceBar({
    required String label,
    required int value,
    required int total,
    required Color color,
  }) {
    final percent = total == 0 ? 0.0 : value / total;
    final percentText = (percent * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                "$value days ($percentText%)",
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 12,
              backgroundColor: Colors.grey.shade300,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
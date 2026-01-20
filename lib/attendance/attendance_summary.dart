import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  String? admissionNo;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    // Safe way to trigger initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMonthlySummary();
    });
  }

  // --------------------------------------------------
  // LOAD MONTHLY SUMMARY (OPTIMIZED)
  // --------------------------------------------------
  Future<void> _loadMonthlySummary() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // ✅ FIX 1: Use FirebaseAuth directly (Safer than context.read in async)
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      // 1. GET CLASS ID & ADMISSION NUMBER
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
        admissionNo = studentDoc.id; // Using Doc ID as Admission No

        if (classId == null || classId!.isEmpty) {
          throw Exception("Class ID not found in profile");
        }
      }

      // 2. GENERATE QUERY FOR THE MONTH
      final firstDay = DateTime(selectedMonth.year, selectedMonth.month, 1);
      final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

      // Start/End Doc IDs for Range Query
      final startDocId =
          '${classId}_${DateFormat('yyyy-MM-dd').format(firstDay)}';

      final nextMonthFirstDay = lastDay.add(const Duration(days: 1));
      final endDocId =
          '${classId}_${DateFormat('yyyy-MM-dd').format(nextMonthFirstDay)}';

      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance_final')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startDocId)
          .where(FieldPath.documentId, isLessThan: endDocId)
          .get();

      // 3. 🚀 OPTIMIZATION: PARALLEL FETCHING
      // Instead of waiting one-by-one, fetch all student statuses in parallel
      List<Future<DocumentSnapshot>> futures = [];

      for (var doc in attendanceSnapshot.docs) {
        futures.add(doc.reference.collection('student').doc(admissionNo).get());
      }

      final studentStatusDocs = await Future.wait(futures);

      // 4. COUNT ATTENDANCE
      int presentCount = 0;
      int halfDayCount = 0;
      int absentCount = 0;
      int totalDaysCount = 0;

      for (var doc in studentStatusDocs) {
        if (doc.exists) {
          totalDaysCount++;
          final data = doc.data() as Map<String, dynamic>?;
          final status = data?['status'] ?? 'absent';

          if (status == 'present') {
            presentCount++;
          } else if (status == 'half-day' || status == 'halfday') {
            halfDayCount++;
          } else {
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF2196F3)),
          ),
          child: child!,
        );
      },
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
      backgroundColor: const Color(0xFFF5F7FA),
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
          ? _buildErrorView()
          : totalDays == 0
          ? _buildEmptyView()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _monthSelector(),
                  const SizedBox(height: 20),
                  _percentageCard(percentage),
                  const SizedBox(height: 20),
                  _buildStatsGrid(),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(errorMessage!, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _loadMonthlySummary,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "No records for ${DateFormat('MMMM').format(selectedMonth)}",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _pickMonth,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              elevation: 0,
              side: const BorderSide(color: Colors.blue),
            ),
            icon: const Icon(Icons.calendar_month),
            label: const Text("Change Month"),
          ),
        ],
      ),
    );
  }

  Widget _monthSelector() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.calendar_month, color: Colors.blue),
        ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              "Attendance Score",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade100,
                    color: color,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${percentage.toStringAsFixed(1)}%",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
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
              child: _statCard("Absent", absent, Colors.red, Icons.cancel),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value.toString(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

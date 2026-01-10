import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:darzo/services/firestore_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMonthlySummary();
  }

  // --------------------------------------------------
  // LOAD MONTHLY SUMMARY (RULE-SAFE)
  // --------------------------------------------------
  Future<void> _loadMonthlySummary() async {
    setState(() => isLoading = true);

    final auth = context.read<AppAuthProvider>();
    final user = auth.user;

    if (user == null) return;

    final student = await FirestoreService.instance.getStudent(user.uid);

    if (student == null) return;

    final classId = student['classId'];

    // ✅ Generate attendance_final doc IDs for the month
    final List<String> attendanceDocIds = _generateAttendanceDocIds(
      classId,
      selectedMonth,
    );

    final result = await FirestoreService.instance.getMonthlyAttendanceSummary(
      studentId: user.uid,
      attendanceDocIds: attendanceDocIds,
    );

    if (!mounted) return;

    setState(() {
      present = result['present'] ?? 0;
      halfDay = result['halfDay'] ?? 0;
      absent = result['absent'] ?? 0;
      totalDays = result['totalDays'] ?? 0;
      isLoading = false;
    });
  }

  // --------------------------------------------------
  // GENERATE DOC IDS (yyyy-MM-dd)
  // --------------------------------------------------
  List<String> _generateAttendanceDocIds(String classId, DateTime month) {
    final List<String> ids = [];

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    for (int i = 0; i < lastDay.day; i++) {
      final date = DateTime(month.year, month.month, i + 1);
      final dateId = DateFormat('yyyy-MM-dd').format(date);
      ids.add('${classId}_$dateId');
    }

    return ids;
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
        ? 0
        : ((present + (halfDay * 0.5)) / totalDays) * 100;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Summary"),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
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
                          style: const TextStyle(
                            fontSize: 30,
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

  // --------------------------------------------------
  // WIDGETS
  // --------------------------------------------------
  Widget _monthSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormat('MMMM yyyy').format(selectedMonth),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ElevatedButton.icon(
          onPressed: _pickMonth,
          icon: const Icon(Icons.calendar_month),
          label: const Text("Change"),
        ),
      ],
    );
  }

  Widget _summaryTile(String title, int value, [Color? color]) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _attendanceBar({
    required String label,
    required int value,
    required int total,
    required Color color,
  }) {
    final percent = total == 0 ? 0.0 : value / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label ($value)"),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percent,
            minHeight: 10,
            backgroundColor: Colors.grey.shade300,
            color: color,
          ),
        ],
      ),
    );
  }
}

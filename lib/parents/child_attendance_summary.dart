import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ParentAttendanceSummaryPage extends StatefulWidget {
  final String admissionNo;
  const ParentAttendanceSummaryPage({super.key, required this.admissionNo});

  @override
  State<ParentAttendanceSummaryPage> createState() =>
      _ParentAttendanceSummaryPageState();
}

class _ParentAttendanceSummaryPageState
    extends State<ParentAttendanceSummaryPage> {
  // Theme Colors
  final Color primaryBlue = const Color(0xFF1565C0);
  final Color bgLight = const Color(0xFFF5F7FA);
  final Color textDark = const Color(0xFF263238);
  final Color textGrey = const Color(0xFF78909C);

  bool _loading = true;
  List<Map<String, dynamic>> _history = [];

  // ✅ FIX: Changed to double to support 0.5 for Half Day
  double total = 0;
  double present = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final db = FirebaseFirestore.instance;

      // 1. Get Student's Class ID
      final studentDoc = await db
          .collection('student')
          .doc(widget.admissionNo)
          .get();

      if (!studentDoc.exists) {
        throw "Student profile not found";
      }

      final classId = studentDoc.data()?['classId']?.toString().trim() ?? '';

      if (classId.isEmpty) {
        throw "Class ID not found for student";
      }

      // 2. Fetch logs
      final classLogsQuery = await db
          .collection('attendance_final')
          .where('classId', isEqualTo: classId)
          .get();

      List<Map<String, dynamic>> tempHistory = [];
      double tempTotal = 0;
      double tempPresent = 0;

      // 3. For each day, check if THIS student was present
      final List<Future<void>> checks = classLogsQuery.docs.map((dayDoc) async {
        try {
          final dayData = dayDoc.data();
          String dateStr = "Unknown";

          if (dayData['date'] != null) {
            if (dayData['date'] is Timestamp) {
              dateStr = (dayData['date'] as Timestamp).toDate().toString();
            } else {
              dateStr = dayData['date'].toString();
            }
          } else {
            final parts = dayDoc.id.split('_');
            if (parts.isNotEmpty && parts.last.contains('-')) {
              dateStr = parts.last;
            }
          }

          final studentLog = await dayDoc.reference
              .collection('student')
              .doc(widget.admissionNo)
              .get();

          if (studentLog.exists) {
            final logData = studentLog.data()!;

            // Determine Status
            bool isPresent =
                logData['present'] == true ||
                logData['status'].toString().toLowerCase() == 'present';

            bool isHalfDay = false;
            if (!isPresent) {
              String statusStr =
                  logData['status']?.toString().toLowerCase() ?? '';
              if (statusStr.contains('half')) isHalfDay = true;
            }

            // ✅ FIX: Scoring Logic
            if (isPresent) {
              tempPresent += 1.0;
            } else if (isHalfDay) {
              tempPresent += 0.5; // Half day counts as 50%
            }

            tempTotal += 1.0; // Increment total days

            tempHistory.add({
              'date': dateStr,
              'status': isPresent
                  ? 'Present'
                  : (isHalfDay ? 'Half Day' : 'Absent'),
              'color': isPresent
                  ? Colors.green
                  : (isHalfDay ? Colors.orange : Colors.red),
              'rawDate': dateStr,
            });
          } else {
            // Absent (Record missing for this student but class had attendance)
            tempTotal += 1.0;
            tempHistory.add({
              'date': dateStr,
              'status': 'Absent',
              'color': Colors.red,
              'rawDate': dateStr,
            });
          }
        } catch (e) {
          debugPrint("Error processing day ${dayDoc.id}: $e");
        }
      }).toList();

      await Future.wait(checks);

      tempHistory.sort((a, b) => b['rawDate'].compareTo(a['rawDate']));

      if (mounted) {
        setState(() {
          _history = tempHistory;
          total = tempTotal;
          present = tempPresent;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching attendance: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double pct = total == 0 ? 0.0 : (present / total) * 100;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "Attendance History",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : Column(
              children: [
                // Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryBlue.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "${pct.toStringAsFixed(1)}%",
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        "Overall Attendance",
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _statItem("Total", _formatNumber(total)),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.white24,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          _statItem("Present", _formatNumber(present)),
                          Container(
                            height: 30,
                            width: 1,
                            color: Colors.white24,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          _statItem("Absent", _formatNumber(total - present)),
                        ],
                      ),
                    ],
                  ),
                ),

                // History List
                Expanded(
                  child: _history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_busy,
                                size: 60,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "No attendance records found",
                                style: TextStyle(color: textGrey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _history.length,
                          itemBuilder: (ctx, i) {
                            final item = _history[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (item['color'] as Color).withOpacity(
                                      0.1,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.circle,
                                    color: item['color'],
                                    size: 12,
                                  ),
                                ),
                                title: Text(
                                  _formatDate(item['date']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (item['color'] as Color).withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    item['status'],
                                    style: TextStyle(
                                      color: item['color'],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }

  // Helper to remove .0 if whole number
  String _formatNumber(double n) {
    if (n == n.roundToDouble()) {
      return n.toInt().toString();
    }
    return n.toString();
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

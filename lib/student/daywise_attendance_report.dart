import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentAttendanceHistoryPage extends StatefulWidget {
  const StudentAttendanceHistoryPage({super.key});

  @override
  State<StudentAttendanceHistoryPage> createState() =>
      _StudentAttendanceHistoryPageState();
}

class _StudentAttendanceHistoryPageState
    extends State<StudentAttendanceHistoryPage> {
  // Theme Colors
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color bgLight = const Color(0xFFF5F7FA);
  final Color textDark = const Color(0xFF263238);
  final Color textGrey = const Color(0xFF78909C);

  bool _loading = true;
  String _studentName = "Loading...";
  String _admissionNo = "";
  List<Map<String, dynamic>> _history = [];
  Map<String, double> _monthlyStats = {}; // Key: "Jan", Value: 0.8 (80%)

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Not logged in";

      // 1. Get Student Profile (Need AdmissionNo & ClassId)
      final studentQuery = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (studentQuery.docs.isEmpty) throw "Student profile not found";

      final studentDoc = studentQuery.docs.first;
      // Use the 'admissionNo' field if available, otherwise doc ID
      final admissionNo = studentDoc.data()['admissionNo'] ?? studentDoc.id;
      final classId = studentDoc.data()['classId'];
      final name = studentDoc.data()['name'] ?? "Student";

      if (classId == null) throw "Class not assigned";

      if (mounted) {
        setState(() {
          _studentName = name;
          _admissionNo = admissionNo;
        });
      }

      // 2. Fetch Class Logs (All days for this class)
      final classLogs = await FirebaseFirestore.instance
          .collection('attendance_final')
          .where('classId', isEqualTo: classId)
          .get();

      List<Map<String, dynamic>> tempHistory = [];
      Map<String, int> monthTotal = {};
      // ✅ FIX: Use double to store score (Present=1.0, HalfDay=0.5)
      Map<String, double> monthScore = {};

      // 3. Check Status for THIS student for each day
      for (var dayDoc in classLogs.docs) {
        final dayData = dayDoc.data();

        // Parse Date
        String dateStr = "Unknown";
        DateTime? dateObj;

        // Try parsing 'date' field (String YYYY-MM-DD or Timestamp)
        if (dayData['date'] != null) {
          if (dayData['date'] is Timestamp) {
            dateObj = (dayData['date'] as Timestamp).toDate();
          } else {
            dateObj = DateTime.tryParse(dayData['date'].toString());
          }
        }

        dateStr = dateObj != null
            ? DateFormat('dd MMM yyyy').format(dateObj)
            : (dayData['date']?.toString() ?? "Unknown");

        // ✅ Fetch subcollection record specifically for THIS student
        final studentLog = await dayDoc.reference
            .collection('student')
            .doc(admissionNo)
            .get();

        String status = "Absent";
        Color color = Colors.red;
        double dayValue = 0.0; // Default 0 for Absent

        // Determine Status based on subcollection data
        if (studentLog.exists) {
          final logData = studentLog.data()!;
          final rawStatus = logData['status'].toString().toLowerCase();

          if (rawStatus == 'present') {
            status = "Present";
            color = Colors.green;
            dayValue = 1.0; // Full Credit
          } else if (rawStatus == 'half-day' || rawStatus.contains('half')) {
            status = "Half Day";
            color = Colors.orange;
            dayValue = 0.5; // ✅ FIX: Half Credit
          }
        }

        tempHistory.add({
          'date': dateStr,
          'status': status,
          'color': color,
          'dateTime': dateObj ?? DateTime(2000),
        });

        // Update Graph Stats
        if (dateObj != null) {
          String monthKey = DateFormat('MMM').format(dateObj); // "Jan", "Feb"
          monthTotal[monthKey] = (monthTotal[monthKey] ?? 0) + 1;

          // Accumulate the score instead of just counting
          monthScore[monthKey] = (monthScore[monthKey] ?? 0.0) + dayValue;
        }
      }

      // Calculate Graph Percentages
      _monthlyStats.clear();
      monthTotal.forEach((key, total) {
        double score = monthScore[key] ?? 0.0;
        // ✅ FIX: Percentage is now (Total Score / Total Days)
        _monthlyStats[key] = total == 0 ? 0.0 : (score / total);
      });

      if (mounted) {
        setState(() {
          _history = tempHistory;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "Attendance Report",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER WITH ADMISSION NO ---
                  Center(
                    child: Column(
                      children: [
                        Text(
                          _studentName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Admission No: $_admissionNo",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- GRAPH SECTION ---
                  const Text(
                    "Monthly Overview",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildMonthlyGraph(),

                  const SizedBox(height: 30),

                  // --- HISTORY LIST SECTION ---
                  const Text(
                    "Day-wise History",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildHistoryList(),
                ],
              ),
            ),
    );
  }

  // Custom Simple Bar Graph
  Widget _buildMonthlyGraph() {
    if (_monthlyStats.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text("No data available yet", style: TextStyle(color: textGrey)),
      );
    }

    // Sort months if needed, here just taking keys
    final keys = _monthlyStats.keys.toList();

    return Container(
      height: 180,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: keys.map((month) {
          final pct = _monthlyStats[month]!;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                "${(pct * 100).toInt()}%",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 6),
              // Bar
              Container(
                width: 12,
                height: (100 * pct).clamp(
                  4.0,
                  100.0,
                ), // Prevent 0 height for tiny values
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                month,
                style: TextStyle(
                  fontSize: 12,
                  color: textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text("No records found", style: TextStyle(color: textGrey)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: textGrey),
                  const SizedBox(width: 10),
                  Text(
                    item['date'],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textDark,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withOpacity(0.1),
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
            ],
          ),
        );
      },
    );
  }
}

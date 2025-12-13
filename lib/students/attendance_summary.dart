import 'package:flutter/material.dart';
import 'package:pie_chart/pie_chart.dart';

class StudentAttendanceSummaryPage extends StatelessWidget {
  const StudentAttendanceSummaryPage({super.key});

  // --------------------------------------------------
  // MOCK ATTENDANCE DATA
  // key = yyyy-MM-dd
  // value: 1.0 = Present, 0.5 = Half Day, 0.0 = Absent
  // --------------------------------------------------
  final Map<String, double> attendanceMap = const {
    "2025-01-02": 1.0,
    "2025-01-03": 1.0,
    "2025-01-04": 0.5,
    "2025-01-05": 0.0,
    "2025-01-06": 1.0,
    "2025-01-07": 1.0,
    "2025-01-08": 1.0,
  };

  @override
  Widget build(BuildContext context) {
    final double totalWorkingDays = attendanceMap.length.toDouble();
    final double totalPresentDays = attendanceMap.values.fold(
      0.0,
      (a, b) => a + b,
    );

    final double attendancePercentage = totalWorkingDays == 0
        ? 0
        : (totalPresentDays / totalWorkingDays) * 100;

    final double absentDays = totalWorkingDays - totalPresentDays;

    Color percentColor = attendancePercentage >= 75 ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text("Attendance Summary"),
        ),
        backgroundColor: const Color(0xFF3F7EDB),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ================= PERCENTAGE =================
            Text(
              "${attendancePercentage.toStringAsFixed(1)}%",
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: percentColor,
              ),
            ),
            const SizedBox(height: 6),
            const Text("Overall Attendance", style: TextStyle(fontSize: 16)),

            const SizedBox(height: 30),

            // ================= PIE CHART =================
            PieChart(
              dataMap: {"Present": totalPresentDays, "Absent": absentDays},
              chartRadius: MediaQuery.of(context).size.width / 2.2,
              chartType: ChartType.ring,
              ringStrokeWidth: 22,
              colorList: const [Colors.green, Colors.red],
              legendOptions: const LegendOptions(
                legendPosition: LegendPosition.bottom,
              ),
              chartValuesOptions: const ChartValuesOptions(
                showChartValuesInPercentage: true,
                showChartValuesOutside: false,
              ),
            ),

            const SizedBox(height: 30),

            // ================= SUMMARY CARDS =================
            Row(
              children: [
                _summaryCard(
                  title: "Present Days",
                  value: totalPresentDays.toStringAsFixed(1),
                  color: Colors.green,
                ),
                const SizedBox(width: 12),
                _summaryCard(
                  title: "Working Days",
                  value: totalWorkingDays.toInt().toString(),
                  color: Colors.blue,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ================= WARNING =================
            if (attendancePercentage < 75)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Warning: Attendance below 75%. You may be restricted from exams.",
                        style: TextStyle(color: Colors.red),
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
  // SUMMARY CARD
  // --------------------------------------------------
  Widget _summaryCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(title),
          ],
        ),
      ),
    );
  }
}

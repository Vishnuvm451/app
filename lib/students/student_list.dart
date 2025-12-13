import 'package:flutter/material.dart';

class StudentStudentsListPage extends StatelessWidget {
  const StudentStudentsListPage({super.key});

  // --------------------------------------------------
  // TEMP MOCK DATA (Replace with Firestore)
  // --------------------------------------------------
  final List<Map<String, dynamic>> students = const [
    {"roll": "01", "name": "Arun", "admissionNo": "ADM001", "attendance": 86.5},
    {"roll": "02", "name": "Bala", "admissionNo": "ADM002", "attendance": 72.0},
    {
      "roll": "03",
      "name": "Charan",
      "admissionNo": "ADM003",
      "attendance": 61.4,
    },
  ];

  // --------------------------------------------------
  // COLOR BASED ON ATTENDANCE %
  // --------------------------------------------------
  Color _attendanceColor(double percent) {
    if (percent >= 75) return Colors.green;
    if (percent >= 65) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text("Classmates"),
        ),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Column(
        children: [
          // ================= HEADER ROW =================
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            color: Colors.blue.shade50,
            child: const Row(
              children: [
                _HeaderCell(text: "Roll", flex: 1),
                _HeaderCell(text: "Name", flex: 3),
                _HeaderCell(text: "Admission No", flex: 3),
                _HeaderCell(text: "Attendance", flex: 2),
              ],
            ),
          ),

          // ================= STUDENT LIST =================
          Expanded(
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final s = students[index];
                final percent = s["attendance"];
                final color = _attendanceColor(percent);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
                    children: [
                      // Roll No
                      _DataCell(text: s["roll"], flex: 1, bold: true),

                      // Name
                      _DataCell(text: s["name"], flex: 3),

                      // Admission No
                      _DataCell(text: s["admissionNo"], flex: 3),

                      // Attendance %
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${percent.toStringAsFixed(1)}%",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------
// HEADER CELL
// --------------------------------------------------
class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;

  const _HeaderCell({required this.text, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}

// --------------------------------------------------
// DATA CELL
// --------------------------------------------------
class _DataCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool bold;

  const _DataCell({required this.text, required this.flex, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

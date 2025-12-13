import 'package:flutter/material.dart';

class StudentListAttendancePage extends StatefulWidget {
  const StudentListAttendancePage({super.key});

  @override
  State<StudentListAttendancePage> createState() =>
      _StudentListAttendancePageState();
}

class _StudentListAttendancePageState extends State<StudentListAttendancePage> {
  // --------------------------------------------------
  // TEMP DATA (Replace with Firestore later)
  // --------------------------------------------------

  final List<String> classes = ["CSE - II Year", "ECE - II Year"];

  String? selectedClass;

  final List<Map<String, dynamic>> students = [
    {"roll": "01", "name": "Arun", "present": 96, "total": 120},
    {"roll": "02", "name": "Bala", "present": 70, "total": 120},
    {"roll": "03", "name": "Charan", "present": 60, "total": 120},
  ];

  // --------------------------------------------------
  // ATTENDANCE % CALCULATION
  // --------------------------------------------------
  double _calculateAttendance(int present, int total) {
    if (total == 0) return 0;
    return (present / total) * 100;
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Students Attendance"),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ================= CLASS DROPDOWN =================
            _buildClassDropdown(),

            const SizedBox(height: 16),

            // ================= STUDENT LIST =================
            if (selectedClass != null) _buildStudentList(),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // CLASS SELECTION
  // --------------------------------------------------
  Widget _buildClassDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedClass,
      hint: const Text("Select Class"),
      items: classes
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (value) {
        setState(() {
          selectedClass = value;

          // 🔥 BACKEND HOOK
          // Fetch students & attendance data for selected class
        });
      },
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // --------------------------------------------------
  // STUDENT LIST VIEW
  // --------------------------------------------------
  Widget _buildStudentList() {
    return Expanded(
      child: ListView.builder(
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          final percentage = _calculateAttendance(
            student["present"],
            student["total"],
          );

          final Color statusColor = percentage >= 75
              ? Colors.green
              : percentage >= 65
              ? Colors.orange
              : Colors.red;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Roll No
                  SizedBox(
                    width: 40,
                    child: Text(
                      student["roll"],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Name
                  Expanded(child: Text(student["name"])),

                  // Attendance %
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${percentage.toStringAsFixed(1)}%",
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

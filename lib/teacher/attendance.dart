import 'dart:async';
import 'package:flutter/material.dart';

class AttendanceDailyPage extends StatefulWidget {
  const AttendanceDailyPage({super.key});

  @override
  State<AttendanceDailyPage> createState() => _AttendanceDailyPageState();
}

class _AttendanceDailyPageState extends State<AttendanceDailyPage> {
  // --------------------------------------------------
  // ASSIGNED CLASS (Fetched after login – mock)
  // --------------------------------------------------
  final String assignedClass = "CSE - II Year";

  // --------------------------------------------------
  // REALTIME DATE & TIME
  // --------------------------------------------------
  late Timer _timer;
  DateTime _now = DateTime.now();

  // --------------------------------------------------
  // ATTENDANCE STATE
  // --------------------------------------------------
  bool attendanceAlreadyMarked = false;

  // --------------------------------------------------
  // STUDENTS (AUTO FETCHED BY CLASS)
  // Default attendance = PRESENT (1.0)
  // --------------------------------------------------
  List<Map<String, dynamic>> students = [];

  @override
  void initState() {
    super.initState();

    _startClock();
    _fetchStudents();
    _checkAttendanceAlreadyMarked();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // --------------------------------------------------
  // REALTIME CLOCK (HH:MM)
  // --------------------------------------------------
  void _startClock() {
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  String get formattedTime {
    final h = _now.hour.toString().padLeft(2, '0');
    final m = _now.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  String get todayDateKey {
    return "${_now.year}-${_now.month.toString().padLeft(2, '0')}-${_now.day.toString().padLeft(2, '0')}";
  }

  String get todayDisplayDate {
    return "${_now.day}/${_now.month}/${_now.year}";
  }

  // --------------------------------------------------
  // FETCH STUDENTS (TEMP MOCK)
  // --------------------------------------------------
  void _fetchStudents() {
    // 🔥 BACKEND HOOK
    // Fetch students where class == assignedClass

    students = [
      {
        "id": "stu1",
        "roll": "01",
        "name": "Arun",
        "admissionNo": "ADM001",
        "attendance": 1.0, // default present
      },
      {
        "id": "stu2",
        "roll": "02",
        "name": "Bala",
        "admissionNo": "ADM002",
        "attendance": 1.0,
      },
      {
        "id": "stu3",
        "roll": "03",
        "name": "Charan",
        "admissionNo": "ADM003",
        "attendance": 1.0,
      },
    ];

    setState(() {});
  }

  // --------------------------------------------------
  // CHECK IF ATTENDANCE ALREADY MARKED (LOGIC)
  // --------------------------------------------------
  Future<void> _checkAttendanceAlreadyMarked() async {
    // 🔥 BACKEND HOOK (Firestore)
    // Check if attendance exists for todayDateKey
    // If exists → attendanceAlreadyMarked = true

    // TEMP MOCK
    attendanceAlreadyMarked = false;

    setState(() {});
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text("Daily Attendance"),
        ),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Column(
        children: [
          // ================= HEADER =================
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Class: $assignedClass",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Date: $todayDisplayDate",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      "Time: $formattedTime",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ================= WARNING =================
          if (attendanceAlreadyMarked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "⚠ Attendance already marked for today",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ),

          // ================= TOTAL STUDENTS =================
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Total Students: ${students.length}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),

          // ================= STUDENT LIST =================
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: students.length,
              itemBuilder: (context, index) {
                final s = students[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(s["name"]),
                    subtitle: Text(
                      "Roll: ${s["roll"]} | Adm: ${s["admissionNo"]}",
                    ),
                    trailing: DropdownButton<double>(
                      value: s["attendance"],
                      items: const [
                        DropdownMenuItem(value: 1.0, child: Text("Present")),
                        DropdownMenuItem(value: 0.5, child: Text("Half Day")),
                        DropdownMenuItem(value: 0.0, child: Text("Absent")),
                      ],
                      onChanged: attendanceAlreadyMarked
                          ? null
                          : (val) {
                              setState(() {
                                s["attendance"] = val!;
                              });
                            },
                    ),
                  ),
                );
              },
            ),
          ),

          // ================= SAVE BUTTON =================
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: attendanceAlreadyMarked ? null : _saveAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Save Attendance"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // SAVE DAILY ATTENDANCE (COLLEGE LOGIC)
  // --------------------------------------------------
  void _saveAttendance() {
    for (var s in students) {
      final studentId = s["id"];
      final value = s["attendance"];

      // 🔥 BACKEND HOOK (Firestore batch)
      // attendance/{studentId} → { todayDateKey : value }
    }

    setState(() {
      attendanceAlreadyMarked = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Attendance saved successfully")),
    );
  }
}

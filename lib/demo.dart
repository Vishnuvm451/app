import 'package:flutter/material.dart';

class TeacherAddTimetablePage extends StatefulWidget {
  const TeacherAddTimetablePage({super.key});

  @override
  State<TeacherAddTimetablePage> createState() =>
      _TeacherAddTimetablePageState();
}

class _TeacherAddTimetablePageState extends State<TeacherAddTimetablePage> {
  final List<String> days = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
  ];
  final List<String> periods = [
    "9:30–10:30",
    "10:40–11:40",
    "11:40–12:40",
    "1:30–2:30",
    "2:30–3:30",
  ];

  // Temporary timetable storage
  Map<String, Map<String, String>> timetable = {};

  @override
  void initState() {
    super.initState();
    for (var day in days) {
      timetable[day] = {};
      for (var p in periods) {
        timetable[day]![p] = "";
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Text("Add Timetable"),
        ),
        backgroundColor: Colors.blue.shade800,
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: [
              const DataColumn(label: Text("Day")),
              ...periods.map((p) => DataColumn(label: Text(p))),
            ],
            rows: days.map((day) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      day,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...periods.map((p) {
                    return DataCell(
                      SizedBox(
                        width: 100,
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: "Subject",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            timetable[day]![p] = value;
                          },
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // 🔥 BACKEND HOOK
          // Save timetable to Firestore
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Timetable saved")));
        },
        label: const Text("Save"),
        icon: const Icon(Icons.save),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class InternalMarksPage extends StatefulWidget {
  const InternalMarksPage({super.key});

  @override
  State<InternalMarksPage> createState() => _InternalMarksPageState();
}

class _InternalMarksPageState extends State<InternalMarksPage> {
  // --------------------------------------------------
  // DROPDOWN DATA (TEMP – later replace with Firebase)
  // --------------------------------------------------

  final List<String> classes = [
    "CS - I Year",
    "CS - II Year",
    "CS - III Year",
    "PG - II Year",
    "PG - II Year",
  ];

  // Class → Subjects mapping
  final Map<String, List<String>> classSubjects = {
    "CS - III Year": ["NETWORK", "OS", "ANDROID", "SS"],
    "ECE - II Year": ["DSP", "VLSI", "EMF"],
  };

  final List<String> internals = ["Internal 1", "Internal 2", "Model Exam"];

  // --------------------------------------------------
  // SELECTED VALUES
  // --------------------------------------------------

  String? selectedClass;
  String? selectedSubject;
  String? selectedInternal;

  // --------------------------------------------------
  // TEMP STUDENT DATA (Replace with Firestore later)
  // --------------------------------------------------

  final List<Map<String, dynamic>> students = [
    {"roll": "01", "name": "Arun", "marks": ""},
    {"roll": "02", "name": "Bala", "marks": ""},
    {"roll": "03", "name": "Charan", "marks": ""},
  ];

  final int maxMarks = 50;

  // --------------------------------------------------
  // UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Internal Marks"),
        backgroundColor: Colors.blue.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ================= CLASS DROPDOWN =================
            _buildDropdown(
              label: "Select Class",
              value: selectedClass,
              items: classes,
              onChanged: (value) {
                setState(() {
                  selectedClass = value;
                  selectedSubject = null;
                  selectedInternal = null;
                });
              },
            ),

            const SizedBox(height: 12),

            // ================= SUBJECT DROPDOWN =================
            _buildDropdown(
              label: "Select Subject",
              value: selectedSubject,
              items: selectedClass == null ? [] : classSubjects[selectedClass]!,
              enabled: selectedClass != null,
              onChanged: (value) {
                setState(() {
                  selectedSubject = value;
                  selectedInternal = null;
                });
              },
            ),

            const SizedBox(height: 12),

            // ================= INTERNAL DROPDOWN =================
            _buildDropdown(
              label: "Select Internal Exam",
              value: selectedInternal,
              items: internals,
              enabled: selectedSubject != null,
              onChanged: (value) {
                setState(() {
                  selectedInternal = value;
                });
              },
            ),

            const SizedBox(height: 20),

            // ================= STUDENT MARKS TABLE =================
            if (selectedClass != null &&
                selectedSubject != null &&
                selectedInternal != null)
              _buildMarksTable(),

            const SizedBox(height: 20),

            // ================= SAVE BUTTON =================
            if (selectedClass != null &&
                selectedSubject != null &&
                selectedInternal != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveMarks,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "Save Marks",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // DROPDOWN WIDGET
  // --------------------------------------------------
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    bool enabled = true,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: enabled ? onChanged : null,
          decoration: InputDecoration(
            hintText: enabled ? "Select" : "Select previous option first",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // STUDENT MARKS TABLE
  // --------------------------------------------------
  Widget _buildMarksTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Enter Marks",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final student = students[index];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Roll No
                    SizedBox(width: 40, child: Text(student["roll"])),

                    // Name
                    Expanded(child: Text(student["name"])),

                    // Marks Field
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: "0-$maxMarks",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (value) {
                          students[index]["marks"] = value;
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --------------------------------------------------
  // SAVE LOGIC (FRONTEND VALIDATION ONLY)
  // --------------------------------------------------
  void _saveMarks() {
    for (var student in students) {
      if (student["marks"].toString().isNotEmpty) {
        final mark = int.tryParse(student["marks"]);
        if (mark == null || mark > maxMarks) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Invalid marks for ${student["name"]}. Max is $maxMarks",
              ),
            ),
          );
          return;
        }
      }
    }

    // 🔥 BACKEND HOOK
    // Save marks to Firestore here

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Marks saved successfully")));
  }
}

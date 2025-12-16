import 'package:darzo/dashboard/teacher_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  final List<Map<String, String>> assignments = [];

  String? department;
  String? selectedClass;
  String? subject;

  bool isSaving = false;

  final departments = ["Computer Science", "Physics", "BCom"];
  final classes = {
    "Computer Science": ["CS1", "CS2", "CS3"],
    "Physics": ["PHY1", "PHY2"],
    "BCom": ["BCOM1", "BCOM2"],
  };

  final subjects = ["OS", "CN", "DBMS", "Maths", "Physics"];

  // --------------------------------------------------
  // ADD ASSIGNMENT
  // --------------------------------------------------
  void addAssignment() {
    if (department == null || selectedClass == null || subject == null) return;

    assignments.add({
      "department": department!,
      "class": selectedClass!,
      "subject": subject!,
    });

    setState(() {
      department = null;
      selectedClass = null;
      subject = null;
    });
  }

  // --------------------------------------------------
  // SAVE TO FIRESTORE (ONE TIME)
  // --------------------------------------------------
  Future<void> saveSetup() async {
    if (assignments.isEmpty) return;

    setState(() => isSaving = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection("teachers").doc(uid).update({
      "assignments": assignments,
      "setupCompleted": true,
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
    );
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Setup"),
        backgroundColor: Colors.blue.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Assign Classes & Subjects",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _dropdown(
              label: "Department",
              value: department,
              items: departments,
              onChanged: (v) {
                setState(() {
                  department = v;
                  selectedClass = null;
                });
              },
            ),

            const SizedBox(height: 12),

            _dropdown(
              label: "Class",
              value: selectedClass,
              items: department == null ? [] : classes[department]!,
              onChanged: (v) => setState(() => selectedClass = v),
            ),

            const SizedBox(height: 12),

            _dropdown(
              label: "Subject",
              value: subject,
              items: subjects,
              onChanged: (v) => setState(() => subject = v),
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: addAssignment,
              child: const Text("Add Assignment"),
            ),

            const SizedBox(height: 20),

            // ASSIGNMENT LIST
            ...assignments.map(
              (a) => ListTile(
                title: Text("${a["subject"]}"),
                subtitle: Text("${a["department"]} - ${a["class"]}"),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SAVE & CONTINUE",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

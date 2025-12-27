import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  String? classId;
  int? semester;
  List<String> selectedSubjects = [];

  String? departmentId;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherDept();
  }

  // --------------------------------------------------
  // LOAD TEACHER DEPARTMENT
  // --------------------------------------------------
  Future<void> _loadTeacherDept() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('teacher') // ✅ FIXED
        .doc(user.uid)
        .get();

    if (!doc.exists) return;

    if (mounted) {
      setState(() {
        departmentId = doc['departmentId'];
      });
    }
  }

  // --------------------------------------------------
  // SAVE SETUP
  // --------------------------------------------------
  Future<void> _saveSetup() async {
    if (classId == null || semester == null || selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select class, semester and subjects"),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    await FirebaseFirestore.instance
        .collection('teacher') // ✅ FIXED
        .doc(user.uid)
        .update({
          'teachingClassId': classId,
          'teachingSemester': semester,
          'subjectIds': selectedSubjects,
          'setupCompleted': true,
        });

    if (!mounted) return;
    Navigator.pop(context);
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (departmentId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Setup"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------------- CLASS ----------------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('classes')
                .where('departmentId', isEqualTo: departmentId)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const CircularProgressIndicator();
              }

              return DropdownButtonFormField<String>(
                value: classId,
                hint: const Text("Select Class"),
                items: snap.data!.docs
                    .map(
                      (d) =>
                          DropdownMenuItem(value: d.id, child: Text(d['name'])),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  classId = v;
                  semester = null;
                  selectedSubjects.clear();
                }),
              );
            },
          ),

          const SizedBox(height: 16),

          // ---------------- SEMESTER ----------------
          DropdownButtonFormField<int>(
            value: semester,
            hint: const Text("Select Semester"),
            items: [1, 2, 3, 4, 5, 6]
                .map(
                  (s) => DropdownMenuItem(value: s, child: Text("Semester $s")),
                )
                .toList(),
            onChanged: (v) => setState(() {
              semester = v;
              selectedSubjects.clear();
            }),
          ),

          const SizedBox(height: 20),

          // ---------------- SUBJECTS ----------------
          if (classId != null && semester != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('subjects')
                  .where('classId', isEqualTo: classId)
                  .where('semester', isEqualTo: semester)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const CircularProgressIndicator();
                }

                if (snap.data!.docs.isEmpty) {
                  return const Text(
                    "No subjects found for this class & semester",
                  );
                }

                return Column(
                  children: snap.data!.docs.map((d) {
                    return CheckboxListTile(
                      title: Text(d['name']),
                      value: selectedSubjects.contains(d.id),
                      onChanged: (v) {
                        setState(() {
                          v == true
                              ? selectedSubjects.add(d.id)
                              : selectedSubjects.remove(d.id);
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 24),

          // ---------------- SAVE BUTTON ----------------
          ElevatedButton(
            onPressed: isSaving ? null : _saveSetup,
            child: isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Save Setup"),
          ),
        ],
      ),
    );
  }
}

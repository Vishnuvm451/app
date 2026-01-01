import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  String? selectedClassId;
  int? selectedSemester;
  List<String> selectedSubjectIds = [];

  String? departmentId;
  bool isSaving = false;
  bool isApproved = false;
  bool setupCompleted = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  // --------------------------------------------------
  // LOAD TEACHER PROFILE
  // --------------------------------------------------
  Future<void> _loadTeacherProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await _db.collection('teacher').doc(user.uid).get();
    if (!snap.exists) return;

    final data = snap.data()!;

    isApproved = data['isApproved'] == true;
    setupCompleted = data['setupCompleted'] == true;

    if (!isApproved) {
      _showSnack("Your account is not approved yet");
      if (mounted) Navigator.pop(context);
      return;
    }

    if (setupCompleted) {
      _showSnack("Setup already completed");
      if (mounted) Navigator.pop(context);
      return;
    }

    if (!mounted) return;
    setState(() {
      departmentId = data['departmentId'];
    });
  }

  // --------------------------------------------------
  // SAVE SETUP
  // --------------------------------------------------
  Future<void> _saveSetup() async {
    if (selectedClassId == null ||
        selectedSemester == null ||
        selectedSubjectIds.isEmpty) {
      _showSnack("Select class, semester and subjects");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    try {
      await _db.collection('teacher').doc(user.uid).update({
        'classId': selectedClassId,
        'semester': selectedSemester,
        'subjectIds': selectedSubjectIds,
        'setupCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnack("Setup completed successfully");
      Navigator.pop(context);
    } catch (e) {
      _showSnack("Failed to save setup");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
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
          _classDropdown(),
          const SizedBox(height: 16),
          _semesterDropdown(),
          const SizedBox(height: 20),
          _subjectsSection(),
          const SizedBox(height: 30),
          _saveButton(),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // CLASS DROPDOWN
  // --------------------------------------------------
  Widget _classDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('class')
          .where('departmentId', isEqualTo: departmentId)
          .orderBy('year')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const LinearProgressIndicator();
        }

        return DropdownButtonFormField<String>(
          value: selectedClassId,
          hint: const Text("Select Class"),
          items: snap.data!.docs.map((d) {
            return DropdownMenuItem(value: d.id, child: Text(d['name']));
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedClassId = val;
              selectedSemester = null;
              selectedSubjectIds.clear();
            });
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.class_),
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // SEMESTER DROPDOWN
  // --------------------------------------------------
  Widget _semesterDropdown() {
    return DropdownButtonFormField<int>(
      value: selectedSemester,
      hint: const Text("Select Semester"),
      items: [1, 2, 3, 4, 5, 6]
          .map((s) => DropdownMenuItem(value: s, child: Text("Semester $s")))
          .toList(),
      onChanged: (val) {
        setState(() {
          selectedSemester = val;
          selectedSubjectIds.clear();
        });
      },
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.calendar_month),
        border: OutlineInputBorder(),
      ),
    );
  }

  // --------------------------------------------------
  // SUBJECTS
  // --------------------------------------------------
  Widget _subjectsSection() {
    if (selectedClassId == null || selectedSemester == null) {
      return const SizedBox();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('subject')
          .where('classId', isEqualTo: selectedClassId)
          .where('semester', isEqualTo: selectedSemester)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const LinearProgressIndicator();
        }

        if (snap.data!.docs.isEmpty) {
          return const Text(
            "No subjects found for this class & semester",
            style: TextStyle(color: Colors.grey),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Subjects",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...snap.data!.docs.map((d) {
              return CheckboxListTile(
                title: Text(d['name']),
                value: selectedSubjectIds.contains(d.id),
                onChanged: (checked) {
                  setState(() {
                    checked == true
                        ? selectedSubjectIds.add(d.id)
                        : selectedSubjectIds.remove(d.id);
                  });
                },
              );
            }),
          ],
        );
      },
    );
  }

  // --------------------------------------------------
  // SAVE BUTTON
  // --------------------------------------------------
  Widget _saveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isSaving ? null : _saveSetup,
        child: isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "Save Setup",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  // --------------------------------------------------
  // SNACK
  // --------------------------------------------------
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

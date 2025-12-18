import 'package:darzo/new/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  bool isLoading = false;

  String? departmentId;
  String? courseType; // UG / PG
  int? year;

  List<int> lockedSemesters = [];
  List<String> selectedSubjectIds = [];

  List<Map<String, dynamic>> departments = [];
  List<Map<String, dynamic>> subjects = [];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  // =====================================================
  // LOAD DEPARTMENTS
  // =====================================================
  Future<void> _loadDepartments() async {
    departments = await FirestoreService.instance.getDepartments();
    setState(() {});
  }

  // =====================================================
  // SEMESTER LOCKING LOGIC (CORE)
  // =====================================================
  void _lockSemesters() {
    if (courseType == null || year == null) return;

    if (courseType == 'UG') {
      lockedSemesters = {
        1: [1, 2],
        2: [3, 4],
        3: [5, 6],
      }[year]!;
    } else {
      lockedSemesters = {
        1: [1, 2],
        2: [3, 4],
      }[year]!;
    }

    _loadSubjects();
  }

  // =====================================================
  // LOAD SUBJECTS (BASED ON LOCKED SEMESTERS)
  // =====================================================
  Future<void> _loadSubjects() async {
    if (departmentId == null || courseType == null) return;

    subjects.clear();
    selectedSubjectIds.clear();

    for (final sem in lockedSemesters) {
      final semSubjects = await FirestoreService.instance.getSubjects(
        departmentId: departmentId!,
        courseType: courseType!,
        semester: sem,
      );
      subjects.addAll(semSubjects);
    }

    setState(() {});
  }

  // =====================================================
  // SAVE SETUP (ONE TIME)
  // =====================================================
  Future<void> _saveSetup() async {
    if (departmentId == null ||
        courseType == null ||
        year == null ||
        selectedSubjectIds.isEmpty) {
      _show("Please complete all fields");
      return;
    }

    setState(() => isLoading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirestoreService.instance.completeTeacherSetup(
      uid: uid,
      classIds: const [], // future use
      subjectIds: selectedSubjectIds,
    );

    if (!mounted) return;

    Navigator.pop(context);
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Setup")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------------- DEPARTMENT ----------------
          _dropdown<String>(
            label: "Department",
            value: departmentId,
            items: departments
                .map(
                  (d) => DropdownMenuItem<String>(
                    value: d['id'] as String,
                    child: Text(d['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                departmentId = v as String?;
                subjects.clear();
                selectedSubjectIds.clear();
                lockedSemesters.clear();
                year = null;
              });
            },
          ),

          // ---------------- COURSE TYPE ----------------
          _dropdown<String>(
            label: "Course Type",
            value: courseType,
            items: const [
              DropdownMenuItem<String>(value: 'UG', child: Text('UG')),
              DropdownMenuItem<String>(value: 'PG', child: Text('PG')),
            ],
            onChanged: (v) {
              setState(() {
                courseType = v as String?;
                year = null;
                lockedSemesters.clear();
                subjects.clear();
              });
            },
          ),

          // ---------------- YEAR ----------------
          _dropdown<int>(
            label: "Year",
            value: year,
            items: [
              const DropdownMenuItem<int>(value: 1, child: Text('1')),
              const DropdownMenuItem<int>(value: 2, child: Text('2')),
              if (courseType == 'UG')
                const DropdownMenuItem<int>(value: 3, child: Text('3')),
            ],
            onChanged: (v) {
              setState(() {
                year = v as int?;
                _lockSemesters();
              });
            },
          ),

          // ---------------- LOCKED SEMESTERS ----------------
          if (lockedSemesters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                "Locked Semesters: ${lockedSemesters.join(', ')}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

          const SizedBox(height: 12),

          // ---------------- SUBJECTS ----------------
          const Text(
            "Select Subjects",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),

          ...subjects.map(
            (s) => CheckboxListTile(
              value: selectedSubjectIds.contains(s['id']),
              title: Text(s['name']),
              onChanged: (checked) {
                setState(() {
                  checked == true
                      ? selectedSubjectIds.add(s['id'])
                      : selectedSubjectIds.remove(s['id']);
                });
              },
            ),
          ),

          const SizedBox(height: 24),

          // ---------------- SAVE ----------------
          ElevatedButton(
            onPressed: isLoading ? null : _saveSetup,
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("SAVE SETUP"),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // GENERIC DROPDOWN HELPER
  // =====================================================
  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

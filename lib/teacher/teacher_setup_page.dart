import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:darzo/teacher/teacher_dashboard.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  String? selectedClassId;
  int? selectedSemester;
  final List<String> selectedSubjectIds = [];

  String? departmentId;
  String? departmentName;

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
  // LOAD TEACHER PROFILE (Updated for Edit Mode)
  // --------------------------------------------------
  Future<void> _loadTeacherProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await _db.collection('teacher').doc(user.uid).get();
    if (!snap.exists) return;

    final data = snap.data()!;

    isApproved = data['isApproved'] == true;
    setupCompleted = data['setupCompleted'] == true;
    departmentId = data['departmentId'];

    if (!isApproved) {
      _showSnack("Your account is not approved yet");
      return;
    }

    // ❌ REMOVED: The block that auto-redirected you to Dashboard.

    // ✅ ADDED: Pre-fill data if editing
    if (setupCompleted) {
      setState(() {
        selectedClassId = data['classId'];
        selectedSemester = data['semester'];
        if (data['subjectIds'] != null) {
          selectedSubjectIds.clear();
          selectedSubjectIds.addAll(List<String>.from(data['subjectIds']));
        }
      });
    }

    // Load department name
    if (departmentId != null) {
      final deptSnap = await _db
          .collection('department')
          .doc(departmentId)
          .get();
      if (deptSnap.exists) {
        setState(() {
          departmentName = deptSnap['name'];
        });
      }
    }
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
        'setupCompleted': true, // Ensure this stays true
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnack("Setup updated successfully");

      // Navigate back to Dashboard (Using pushReplacement to refresh dashboard state)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
      );
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
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text("Edit Setup"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(),
          const SizedBox(height: 16),
          _classCard(),
          const SizedBox(height: 16),
          _semesterCard(),
          const SizedBox(height: 16),
          _subjectsCard(),
          const SizedBox(height: 30),
          _saveButton(),
        ],
      ),
    );
  }

  Widget _infoCard() {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.apartment),
        title: const Text("Department"),
        subtitle: Text(departmentName ?? "—"),
      ),
    );
  }

  Widget _classCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('class')
              .where('departmentId', isEqualTo: departmentId)
              .snapshots(),
          builder: (_, snap) {
            if (snap.hasError) return const Text("Error loading classes");
            if (!snap.hasData) return const LinearProgressIndicator();

            final docs = snap.data!.docs;
            // Sort locally to avoid index errors
            docs.sort((a, b) {
              final yearA = (a.data() as Map)['year'] ?? 0;
              final yearB = (b.data() as Map)['year'] ?? 0;
              return yearA.compareTo(yearB);
            });

            if (docs.isEmpty) {
              return const Text("No classes found for this department");
            }

            // Ensure selectedClassId is valid (if class was deleted)
            if (selectedClassId != null &&
                !docs.any((d) => d.id == selectedClassId)) {
              selectedClassId = null;
            }

            return DropdownButtonFormField<String>(
              value: selectedClassId,
              hint: const Text("Select Class"),
              items: docs.map((d) {
                return DropdownMenuItem(value: d.id, child: Text(d['name']));
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedClassId = val;
                  // If class changes, we might want to clear subjects,
                  // but for "Edit" we often keep semester.
                  selectedSubjectIds.clear();
                });
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.class_),
                border: OutlineInputBorder(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _semesterCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<int>(
          value: selectedSemester,
          hint: const Text("Select Semester"),
          items: [1, 2, 3, 4, 5, 6]
              .map(
                (s) => DropdownMenuItem(value: s, child: Text("Semester $s")),
              )
              .toList(),
          onChanged: (val) {
            setState(() {
              selectedSemester = val;
              selectedSubjectIds.clear(); // Clear subjects if semester changes
            });
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.calendar_month),
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }

  Widget _subjectsCard() {
    if (selectedClassId == null || selectedSemester == null) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('subject')
              .where('classId', isEqualTo: selectedClassId)
              .where('semester', isEqualTo: selectedSemester)
              .snapshots(),
          builder: (_, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();

            if (snap.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "No subjects found for this semester",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Select Subjects",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                ...snap.data!.docs.map((d) {
                  final id = d.id;
                  return CheckboxListTile(
                    title: Text(d['name']),
                    value: selectedSubjectIds.contains(id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          if (!selectedSubjectIds.contains(id)) {
                            selectedSubjectIds.add(id);
                          }
                        } else {
                          selectedSubjectIds.remove(id);
                        }
                      });
                    },
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isSaving ? null : _saveSetup,
        child: isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "Save Changes",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

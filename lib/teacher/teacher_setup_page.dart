import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/dashboard/teacher_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  String? selectedDepartmentId;

  final List<String> selectedClasses = [];
  final List<String> selectedSubjects = [];

  bool isLoading = false;

  // --------------------------------------------------
  // SAVE PROFILE
  // --------------------------------------------------
  Future<void> _saveProfile() async {
    if (selectedDepartmentId == null ||
        selectedClasses.isEmpty ||
        selectedSubjects.isEmpty) {
      _snack("Select department, classes & subjects");
      return;
    }

    setState(() => isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection("teachers").doc(uid).set({
        "departmentId": selectedDepartmentId,
        "classes": selectedClasses,
        "subjects": selectedSubjects,
        "setupCompleted": true,
        "updated_at": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "profile_completed": true,
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
        );
      }
    } catch (e) {
      _snack("Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2196F3);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Teacher Setup"),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Select Department"),
                  _departmentDropdown(),

                  const SizedBox(height: 24),
                  _sectionTitle("Select Classes"),
                  _classList(),

                  const SizedBox(height: 24),
                  _sectionTitle("Select Subjects"),
                  _subjectList(),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "SAVE & CONTINUE",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --------------------------------------------------
  // DEPARTMENT
  // --------------------------------------------------
  Widget _departmentDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("departments")
          .where("active", isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        return DropdownButtonFormField<String>(
          value: selectedDepartmentId,
          hint: const Text("Choose Department"),
          items: snap.data!.docs.map((d) {
            return DropdownMenuItem(value: d.id, child: Text(d["name"]));
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedDepartmentId = val;
              selectedClasses.clear();
              selectedSubjects.clear();
            });
          },
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      },
    );
  }

  // --------------------------------------------------
  // CLASSES
  // --------------------------------------------------
  Widget _classList() {
    if (selectedDepartmentId == null) {
      return const Text("Select department first");
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("classes")
          .where("departmentId", isEqualTo: selectedDepartmentId)
          .where("active", isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final docs = snap.data!.docs;

        final ordered = [
          ...docs.where((d) => selectedClasses.contains(d["name"])),
          ...docs.where((d) => !selectedClasses.contains(d["name"])),
        ];

        return Column(
          children: ordered.map((doc) {
            final name = doc["name"];
            return CheckboxListTile(
              title: Text(name),
              value: selectedClasses.contains(name),
              onChanged: (val) {
                setState(() {
                  val == true
                      ? selectedClasses.add(name)
                      : selectedClasses.remove(name);
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  // --------------------------------------------------
  // SUBJECTS (AUTO-MAPPED TO CLASSES)
  // --------------------------------------------------
  Widget _subjectList() {
    if (selectedDepartmentId == null) {
      return const Text("Select department first");
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("subjects")
          .where("departmentId", isEqualTo: selectedDepartmentId)
          .where("active", isEqualTo: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final docs = snap.data!.docs.where((doc) {
          final List classes = doc["classes"];
          return classes.any((c) => selectedClasses.contains(c));
        }).toList();

        final ordered = [
          ...docs.where((d) => selectedSubjects.contains(d["name"])),
          ...docs.where((d) => !selectedSubjects.contains(d["name"])),
        ];

        return Column(
          children: ordered.map((doc) {
            final name = doc["name"];
            return CheckboxListTile(
              title: Text(name),
              value: selectedSubjects.contains(name),
              onChanged: (val) {
                setState(() {
                  val == true
                      ? selectedSubjects.add(name)
                      : selectedSubjects.remove(name);
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

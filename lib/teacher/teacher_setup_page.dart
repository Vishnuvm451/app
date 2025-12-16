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
  // ---------------------------------------------------
  // DATA: Hardcoded lists for now (You can fetch these later)
  // ---------------------------------------------------
  final List<String> availableClasses = [
    "BSc CS - Year 1",
    "BSc CS - Year 2",
    "BSc CS - Year 3",
    "BSc Physics - Year 1",
    "BCom - Year 1",
  ];

  final List<String> availableSubjects = [
    "Java Programming",
    "Data Structures",
    "Web Development",
    "Digital Electronics",
    "Mathematics",
    "Physics I",
    "Accounting",
  ];

  // ---------------------------------------------------
  // STATE: What the teacher has selected
  // ---------------------------------------------------
  final List<String> selectedClasses = [];
  final List<String> selectedSubjects = [];
  bool isLoading = false;

  // ---------------------------------------------------
  // LOGIC: Save choices & complete profile
  // ---------------------------------------------------
  Future<void> _saveProfile() async {
    if (selectedClasses.isEmpty || selectedSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least 1 Class and 1 Subject"),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // 1. Update TEACHER details
      await FirebaseFirestore.instance.collection('teachers').doc(uid).update({
        'classes': selectedClasses,
        'subjects': selectedSubjects,
        'setupCompleted': true,
      });

      // 2. Update USER profile (so they don't see this page again)
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profile_completed': true,
      });

      if (mounted) {
        // 3. Go to Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving profile: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------------------------------------------
  // HELPER: Toggle Selection
  // ---------------------------------------------------
  void _onClassChanged(bool? selected, String className) {
    setState(() {
      selected == true
          ? selectedClasses.add(className)
          : selectedClasses.remove(className);
    });
  }

  void _onSubjectChanged(bool? selected, String subjectName) {
    setState(() {
      selected == true
          ? selectedSubjects.add(subjectName)
          : selectedSubjects.remove(subjectName);
    });
  }

  // ===================================================
  // UI
  // ===================================================
  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2196F3);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Setup"),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome, Teacher!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Please select the classes and subjects you will be teaching.",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    // --- CLASSES SECTION ---
                    const Text(
                      "Select Classes",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...availableClasses.map(
                      (cls) => CheckboxListTile(
                        title: Text(cls),
                        value: selectedClasses.contains(cls),
                        activeColor: primaryBlue,
                        onChanged: (val) => _onClassChanged(val, cls),
                      ),
                    ),

                    const Divider(height: 40, thickness: 1),

                    // --- SUBJECTS SECTION ---
                    const Text(
                      "Select Subjects",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...availableSubjects.map(
                      (sub) => CheckboxListTile(
                        title: Text(sub),
                        value: selectedSubjects.contains(sub),
                        activeColor: primaryBlue,
                        onChanged: (val) => _onSubjectChanged(val, sub),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- SAVE BUTTON ---
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}

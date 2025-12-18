import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/ZIP/teacher_dashboard.dart';
import 'package:darzo/ZIP/login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  // ---------------- SELECTIONS ----------------
  String? selectedDepartmentId;
  String? selectedDeptName; // Saved for display
  String? selectedCourseType; // "UG" or "PG"
  String? selectedSemester; // "Semester 1", "Semester 2"...

  // Stores IDs (e.g. "CSE_SECTION_A", "CS101")
  final Set<String> selectedClassIds = {};
  final Set<String> selectedSubjectIds = {};

  // For displaying selected items as chips
  final Map<String, String> subjectNames = {}; // ID -> Name map

  bool isLoading = false;
  static const Color primaryBlue = Color(0xFF2196F3);

  // ---------------- STATIC DATA ----------------
  final List<String> courseTypes = ["UG", "PG"];

  List<String> get currentSemesterList {
    if (selectedCourseType == "UG") {
      return List.generate(8, (index) => "Semester ${index + 1}");
    } else if (selectedCourseType == "PG") {
      return List.generate(4, (index) => "Semester ${index + 1}");
    }
    return [];
  }

  // ---------------- NAVIGATION ----------------
  Future<void> _goBackToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  // ---------------- SAVE PROFILE ----------------
  Future<void> _saveProfile() async {
    if (selectedDepartmentId == null ||
        selectedClassIds.isEmpty ||
        selectedSubjectIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select Department, Classes, and Subjects"),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // 1. Update Teacher Profile
      await FirebaseFirestore.instance.collection("teachers").doc(uid).update({
        "departmentId": selectedDepartmentId,
        "departmentName": selectedDeptName,
        "classIds": selectedClassIds.toList(), // List of Class IDs
        "subjectIds": selectedSubjectIds.toList(), // List of Subject IDs
        "setupCompleted": true,
      });

      // 2. Update User Role Status
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _goBackToLogin();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text("Teacher Setup"),
          backgroundColor: primaryBlue,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBackToLogin,
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. DEPARTMENT
                    _sectionTitle("1. Select Department"),
                    _departmentDropdown(),

                    const SizedBox(height: 20),

                    // 2. COURSE TYPE
                    _sectionTitle("2. Select Course Type"),
                    _ugPgDropdown(),

                    const SizedBox(height: 20),

                    // 3. CLASSES
                    if (selectedDepartmentId != null &&
                        selectedCourseType != null) ...[
                      _sectionTitle("3. Select Classes"),
                      const Text(
                        "Check the classes you teach:",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      _classList(),
                    ],

                    const SizedBox(height: 20),

                    // 4. SUBJECTS (Semester Filter)
                    if (selectedDepartmentId != null &&
                        selectedCourseType != null) ...[
                      _sectionTitle("4. Select Subjects"),
                      const Text(
                        "Filter by Semester to find subjects:",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      _semesterDropdown(),
                      const SizedBox(height: 8),
                      if (selectedSemester != null) _subjectList(),

                      const SizedBox(height: 20),

                      // Display Selected Chips
                      if (selectedSubjectIds.isNotEmpty) ...[
                        const Text(
                          "Selected Subjects:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildSelectedSubjectChips(),
                      ],
                    ],

                    const SizedBox(height: 40),

                    // SAVE BUTTON
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

  // ---------------- WIDGETS ----------------

  Widget _departmentDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("departments")
          .orderBy("name")
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();

        return DropdownButtonFormField<String>(
          value: selectedDepartmentId,
          hint: const Text("Select Department"),
          items: snap.data!.docs.map((d) {
            // Value is ID ("CSE"), Child is Name ("Computer Science")
            return DropdownMenuItem(value: d.id, child: Text(d["name"]));
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedDepartmentId = val;
              if (val != null) {
                selectedDeptName = snap.data!.docs.firstWhere(
                  (d) => d.id == val,
                )["name"];
              }
              selectedClassIds.clear();
              selectedSubjectIds.clear();
              subjectNames.clear();
            });
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
        );
      },
    );
  }

  Widget _ugPgDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedCourseType,
      hint: const Text("UG or PG"),
      items: courseTypes
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (val) {
        setState(() {
          selectedCourseType = val;
          selectedSemester = null;
          // Don't clear selections here, they might teach UG and PG
        });
      },
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _semesterDropdown() {
    return DropdownButtonFormField<String>(
      value: selectedSemester,
      hint: const Text("Select Semester to View Subjects"),
      items: currentSemesterList
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (val) => setState(() => selectedSemester = val),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _classList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("classes")
          .where("departmentId", isEqualTo: selectedDepartmentId)
          .where("type", isEqualTo: selectedCourseType)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty) return const Text("No classes found.");

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Column(
            children: snap.data!.docs.map((doc) {
              final name = doc["name"];
              final id = doc.id; // Manual ID: "CSE_SECTION_A"

              return CheckboxListTile(
                title: Text(name),
                value: selectedClassIds.contains(id),
                activeColor: primaryBlue,
                dense: true,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      selectedClassIds.add(id);
                    } else {
                      selectedClassIds.remove(id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _subjectList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("subjects")
          .where("departmentId", isEqualTo: selectedDepartmentId)
          .where("type", isEqualTo: selectedCourseType)
          .where("semester", isEqualTo: selectedSemester)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snap.data!.docs.isEmpty)
          return const Text("No subjects found for this semester.");

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Column(
            children: snap.data!.docs.map((doc) {
              final name = doc["name"];
              final id = doc.id; // Manual ID: "CS101"

              return CheckboxListTile(
                title: Text(name),
                subtitle: Text(
                  "Code: $id",
                  style: const TextStyle(fontSize: 11),
                ),
                value: selectedSubjectIds.contains(id),
                activeColor: primaryBlue,
                dense: true,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      selectedSubjectIds.add(id);
                      subjectNames[id] = name; // Store name for chip display
                    } else {
                      selectedSubjectIds.remove(id);
                      subjectNames.remove(id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSelectedSubjectChips() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: selectedSubjectIds.map((id) {
        final name = subjectNames[id] ?? id;
        return Chip(
          label: Text(name),
          backgroundColor: Colors.blue.shade50,
          deleteIcon: const Icon(Icons.close, size: 18),
          onDeleted: () {
            setState(() {
              selectedSubjectIds.remove(id);
              subjectNames.remove(id);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryBlue,
        ),
      ),
    );
  }
}

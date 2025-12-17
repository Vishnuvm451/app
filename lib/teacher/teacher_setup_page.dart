import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/dashboard/teacher_dashboard.dart';
import 'package:darzo/login.dart';
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
  String? selectedCourseType; // "UG" or "PG"
  String? selectedSemester; // "Semester 1", "Semester 2"...

  final List<String> selectedClasses = [];
  final List<String> selectedSubjects = [];

  final TextEditingController _subjectSearchController =
      TextEditingController();

  bool isLoading = false;
  static const Color primaryBlue = Color(0xFF2196F3);

  // ---------------- STATIC DATA ----------------
  final List<String> courseTypes = ["UG", "PG"];

  List<String> get currentSemesterList {
    if (selectedCourseType == "UG") {
      return List.generate(6, (index) => "Semester ${index + 1}");
    } else if (selectedCourseType == "PG") {
      return List.generate(4, (index) => "Semester ${index + 1}");
    }
    return [];
  }

  // ---------------- NAVIGATION ----------------
  Future<void> _goBackToLogin() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ---------------- SAVE PROFILE ----------------
  Future<void> _saveProfile() async {
    if (selectedDepartmentId == null ||
        selectedClasses.isEmpty ||
        selectedSubjects.isEmpty) {
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

      await FirebaseFirestore.instance.collection("teachers").doc(uid).update({
        "departmentId": selectedDepartmentId,
        "classes": selectedClasses,
        "subjects": selectedSubjects,
        "setupCompleted": true,
      });

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

                    // 3. SEMESTER
                    _sectionTitle("3. Select Semester"),
                    _semesterDropdown(),

                    const SizedBox(height: 20),

                    // 4. CLASSES
                    if (selectedDepartmentId != null &&
                        selectedCourseType != null) ...[
                      _sectionTitle("4. Select Classes (Years)"),
                      const Text(
                        "Check the classes you teach:",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      _classList(),
                    ],

                    const SizedBox(height: 20),

                    // 5. SUBJECTS
                    if (selectedDepartmentId != null &&
                        selectedCourseType != null &&
                        selectedSemester != null) ...[
                      _sectionTitle("5. Select Subjects"),
                      const Text(
                        "Check the subjects you teach in this semester:",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      _subjectList(),

                      const SizedBox(height: 20),

                      _sectionTitle("Additional Subjects (Optional)"),

                      // 🟢 NEW: Display Selected Subjects as Chips
                      if (selectedSubjects.isNotEmpty) ...[
                        _buildSelectedSubjectChips(),
                        const SizedBox(height: 10),
                      ],

                      _additionalSubjectSearch(),
                      _selectedAdditionalSubjects(),
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
          items: snap.data!.docs
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d["name"])))
              .toList(),
          onChanged: (val) {
            setState(() {
              selectedDepartmentId = val;
              selectedClasses.clear();
              selectedSubjects.clear();
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
    if (selectedCourseType == null) {
      return const Text(
        "Select Course Type first",
        style: TextStyle(color: Colors.grey),
      );
    }
    return DropdownButtonFormField<String>(
      value: selectedSemester,
      hint: const Text("Select Semester"),
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
              return CheckboxListTile(
                title: Text(name),
                value: selectedClasses.contains(name),
                activeColor: primaryBlue,
                dense: true,
                onChanged: (val) {
                  setState(() {
                    if (val == true)
                      selectedClasses.add(name);
                    else
                      selectedClasses.remove(name);
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
              return CheckboxListTile(
                title: Text(name),
                value: selectedSubjects.contains(name),
                activeColor: primaryBlue,
                dense: true,
                onChanged: (val) {
                  setState(() {
                    if (val == true)
                      selectedSubjects.add(name);
                    else
                      selectedSubjects.remove(name);
                  });
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // 🟢 NEW: Selected Chips Display
  Widget _buildSelectedSubjectChips() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: selectedSubjects.map((subject) {
        return Chip(
          label: Text(subject),
          backgroundColor: Colors.blue.shade50,
          deleteIcon: const Icon(Icons.close, size: 18),
          onDeleted: () {
            setState(() {
              selectedSubjects.remove(subject);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _additionalSubjectSearch() {
    return TextField(
      controller: _subjectSearchController,
      decoration: const InputDecoration(
        hintText: "Search other subjects...",
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _selectedAdditionalSubjects() {
    final query = _subjectSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("subjects")
          .where("name_lower", isGreaterThanOrEqualTo: query)
          .where("name_lower", isLessThanOrEqualTo: "$query\uf8ff")
          .orderBy("name_lower")
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox();

        final results = snap.data!.docs.where((doc) {
          final name = doc["name"];
          return !selectedSubjects.contains(name);
        }).toList();

        if (results.isEmpty)
          return const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text("No matching subjects found."),
          );

        return Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Column(
            children: results.map((doc) {
              final name = doc["name"];
              final sem = doc["semester"] ?? "";
              return ListTile(
                title: Text(name),
                subtitle: Text(sem, style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.add, color: primaryBlue),
                dense: true,
                onTap: () {
                  setState(() {
                    selectedSubjects.add(name);
                    _subjectSearchController.clear();
                  });
                },
              );
            }).toList(),
          ),
        );
      },
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

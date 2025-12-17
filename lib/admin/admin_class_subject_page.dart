import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminClassSubjectPage extends StatefulWidget {
  const AdminClassSubjectPage({super.key});

  @override
  State<AdminClassSubjectPage> createState() => _AdminClassSubjectPageState();
}

class _AdminClassSubjectPageState extends State<AdminClassSubjectPage> {
  // ---------------- CONTROLLERS ----------------
  final _deptController = TextEditingController();
  final _classController = TextEditingController(); // For "CS1", "CS2"
  final _subjectController = TextEditingController();

  // ---------------- SELECTIONS ----------------
  String? selectedDeptId;
  String? selectedCourseType; // "UG" or "PG"
  String? selectedSemester; // "Semester 1", "Semester 2"...
  List<String> selectedSubjectClasses = [];

  bool isLoading = false;
  static const Color primaryBlue = Color(0xFF2196F3);

  // ---------------- STATIC DATA ----------------
  final List<String> courseTypes = ["UG", "PG"];

  // Dynamic semester list getter
  List<String> get currentSemesterList {
    if (selectedCourseType == "UG") {
      return List.generate(6, (index) => "Semester ${index + 1}");
    } else if (selectedCourseType == "PG") {
      return List.generate(4, (index) => "Semester ${index + 1}");
    }
    return [];
  }

  // ==================================================
  // UI BUILD
  // ==================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Manage Academics"),
        backgroundColor: primaryBlue,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. ADD DEPARTMENT
                  _buildCard(
                    title: "1. Add Department",
                    children: [
                      _textField(
                        _deptController,
                        "Department Name (e.g. Computer Science)",
                      ),
                      const SizedBox(height: 12),
                      _saveButton("Save Department", _addDepartment),
                    ],
                  ),

                  // 2. ADD CLASS (YEAR)
                  _buildCard(
                    title: "2. Add Class / Year",
                    children: [
                      _departmentDropdown(),
                      const SizedBox(height: 12),
                      _ugPgDropdown(isForClass: true), // Resets sem if changed
                      const SizedBox(height: 12),
                      _textField(
                        _classController,
                        "Class Name (e.g. CS1, CS2, BCA-I)",
                      ),
                      const SizedBox(height: 12),
                      _saveButton("Save Class", _addClass),
                    ],
                  ),

                  // 3. ADD SUBJECT (SEMESTER WISE)
                  _buildCard(
                    title: "3. Add Subject",
                    children: [
                      _departmentDropdown(),
                      const SizedBox(height: 12),
                      _ugPgDropdown(isForClass: false),
                      const SizedBox(height: 12),
                      _semesterDropdown(), // Dynamic based on UG/PG
                      const SizedBox(height: 12),
                      _textField(_subjectController, "Subject Name"),
                      const SizedBox(height: 12),
                      const Text(
                        "Select Classes for this Subject:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      _classMultiSelect(), // Filters by Dept + UG/PG
                      const SizedBox(height: 12),
                      _saveButton("Save Subject", _addSubject),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // ==================================================
  // WIDGET HELPERS
  // ==================================================

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryBlue,
              ),
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _textField(TextEditingController c, String hint) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _saveButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ---------------- DROPDOWNS ----------------

  Widget _departmentDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("departments")
          .orderBy("name")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();

        return DropdownButtonFormField<String>(
          value: selectedDeptId,
          decoration: const InputDecoration(
            labelText: "Select Department",
            border: OutlineInputBorder(),
          ),
          items: snapshot.data!.docs.map((doc) {
            return DropdownMenuItem(value: doc.id, child: Text(doc["name"]));
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedDeptId = val;
              selectedSubjectClasses.clear();
            });
          },
        );
      },
    );
  }

  Widget _ugPgDropdown({required bool isForClass}) {
    return DropdownButtonFormField<String>(
      value: selectedCourseType,
      decoration: const InputDecoration(
        labelText: "Select Course Type",
        border: OutlineInputBorder(),
      ),
      items: courseTypes
          .map((type) => DropdownMenuItem(value: type, child: Text(type)))
          .toList(),
      onChanged: (val) {
        setState(() {
          selectedCourseType = val;
          selectedSemester = null; // Reset semester if type changes
          selectedSubjectClasses.clear(); // Clear class selection
        });
      },
    );
  }

  Widget _semesterDropdown() {
    // Only show if UG/PG is selected
    if (selectedCourseType == null) {
      return const SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Text(
            "Select UG/PG to view Semesters",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: selectedSemester,
      decoration: const InputDecoration(
        labelText: "Select Semester",
        border: OutlineInputBorder(),
      ),
      items: currentSemesterList
          .map((sem) => DropdownMenuItem(value: sem, child: Text(sem)))
          .toList(),
      onChanged: (val) => setState(() => selectedSemester = val),
    );
  }

  Widget _classMultiSelect() {
    if (selectedDeptId == null || selectedCourseType == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          "Select Department & Course Type first.",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    // Filter classes by Dept AND UG/PG
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("classes")
          .where("departmentId", isEqualTo: selectedDeptId)
          .where(
            "type",
            isEqualTo: selectedCourseType,
          ) // Filter strictly by UG/PG
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        if (snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "No classes found. Add a Class above first.",
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: snapshot.data!.docs.map((doc) {
              final name = doc["name"];
              return CheckboxListTile(
                dense: true,
                title: Text(name),
                value: selectedSubjectClasses.contains(name),
                activeColor: primaryBlue,
                onChanged: (val) {
                  setState(() {
                    val == true
                        ? selectedSubjectClasses.add(name)
                        : selectedSubjectClasses.remove(name);
                  });
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ==================================================
  // FIRESTORE LOGIC
  // ==================================================

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addDepartment() async {
    final name = _deptController.text.trim();
    if (name.isEmpty) return _showSnack("Enter department name");

    setState(() => isLoading = true);

    // Check Duplicate
    final existing = await FirebaseFirestore.instance
        .collection("departments")
        .where("name_lower", isEqualTo: name.toLowerCase())
        .get();

    if (existing.docs.isNotEmpty) {
      setState(() => isLoading = false);
      return _showSnack("Department already exists!");
    }

    await FirebaseFirestore.instance.collection("departments").add({
      "name": name,
      "name_lower": name.toLowerCase(),
      "created_at": FieldValue.serverTimestamp(),
    });

    _deptController.clear();
    setState(() => isLoading = false);
    _showSnack("Department Added!");
  }

  Future<void> _addClass() async {
    if (selectedDeptId == null || selectedCourseType == null) {
      return _showSnack("Select Department and UG/PG");
    }
    final name = _classController.text.trim();
    if (name.isEmpty) return _showSnack("Enter class name");

    setState(() => isLoading = true);

    // Check Duplicate: Same Name + Same Dept + Same Type
    final existing = await FirebaseFirestore.instance
        .collection("classes")
        .where("name_lower", isEqualTo: name.toLowerCase())
        .where("departmentId", isEqualTo: selectedDeptId)
        .where("type", isEqualTo: selectedCourseType)
        .get();

    if (existing.docs.isNotEmpty) {
      setState(() => isLoading = false);
      return _showSnack("Class already exists in this Department/Type!");
    }

    await FirebaseFirestore.instance.collection("classes").add({
      "name": name,
      "name_lower": name.toLowerCase(),
      "departmentId": selectedDeptId,
      "type": selectedCourseType, // UG or PG
      "created_at": FieldValue.serverTimestamp(),
    });

    _classController.clear();
    setState(() => isLoading = false);
    _showSnack("Class Added!");
  }

  Future<void> _addSubject() async {
    if (selectedDeptId == null ||
        selectedCourseType == null ||
        selectedSemester == null) {
      return _showSnack("Select Dept, UG/PG and Semester");
    }
    final name = _subjectController.text.trim();
    if (name.isEmpty) return _showSnack("Enter subject name");
    if (selectedSubjectClasses.isEmpty)
      return _showSnack("Select at least one class");

    setState(() => isLoading = true);

    // Check Duplicate: Same Subject Name in Same Dept & Semester
    final existing = await FirebaseFirestore.instance
        .collection("subjects")
        .where("name_lower", isEqualTo: name.toLowerCase())
        .where("departmentId", isEqualTo: selectedDeptId)
        .where("semester", isEqualTo: selectedSemester)
        .get();

    if (existing.docs.isNotEmpty) {
      setState(() => isLoading = false);
      return _showSnack("Subject already exists in this Semester!");
    }

    await FirebaseFirestore.instance.collection("subjects").add({
      "name": name,
      "name_lower": name.toLowerCase(),
      "departmentId": selectedDeptId,
      "type": selectedCourseType,
      "semester": selectedSemester, // e.g. "Semester 1"
      "classes": selectedSubjectClasses, // Linked Classes
      "created_at": FieldValue.serverTimestamp(),
    });

    _subjectController.clear();
    selectedSubjectClasses.clear();
    setState(() => isLoading = false);
    _showSnack("Subject Added!");
  }
}

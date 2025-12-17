import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminClassSubjectPage extends StatefulWidget {
  const AdminClassSubjectPage({super.key});

  @override
  State<AdminClassSubjectPage> createState() => _AdminClassSubjectPageState();
}

class _AdminClassSubjectPageState extends State<AdminClassSubjectPage> {
  // ---------------- CONTROLLERS ----------------
  // Just Names now (IDs will be auto-generated)
  final _deptNameController = TextEditingController();
  final _classNameController = TextEditingController();

  // Subject needs Code (unique) and Name
  final _subjectNameController = TextEditingController();
  final _subjectCodeController = TextEditingController();

  // ---------------- SELECTIONS ----------------
  String? selectedDeptId;
  String? selectedCourseType; // "UG" or "PG"
  String? selectedSemester;

  List<String> selectedClassIds = [];
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
                  // 1. ADD DEPARTMENT (Simplified)
                  _buildCard(
                    title: "1. Add Department",
                    children: [
                      _textField(
                        _deptNameController,
                        "Department Name (e.g. Computer Science)",
                      ),
                      const SizedBox(height: 12),
                      _saveButton("Save Department", _addDepartment),
                    ],
                  ),

                  // 2. ADD CLASS (Simplified)
                  _buildCard(
                    title: "2. Add Class / Section",
                    children: [
                      _departmentDropdown(),
                      const SizedBox(height: 12),
                      _ugPgDropdown(isForClass: true),
                      const SizedBox(height: 12),
                      _textField(
                        _classNameController,
                        "Class Name (e.g. Section A)",
                      ),
                      const SizedBox(height: 12),
                      _saveButton("Save Class", _addClass),
                    ],
                  ),

                  // 3. ADD SUBJECT
                  _buildCard(
                    title: "3. Add Subject",
                    children: [
                      _departmentDropdown(),
                      const SizedBox(height: 12),
                      _ugPgDropdown(isForClass: false),
                      const SizedBox(height: 12),
                      _semesterDropdown(),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _textField(
                              _subjectCodeController,
                              "Code (CS101)",
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _textField(
                              _subjectNameController,
                              "Subject Name",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Select Classes for this Subject:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      _classMultiSelect(),
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
              selectedClassIds.clear();
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
          selectedSemester = null;
          selectedClassIds.clear();
        });
      },
    );
  }

  Widget _semesterDropdown() {
    if (selectedCourseType == null) {
      return const SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.all(12.0),
          child: Text(
            "Select UG/PG first",
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

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("classes")
          .where("departmentId", isEqualTo: selectedDeptId)
          .where("type", isEqualTo: selectedCourseType)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        if (snapshot.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "No classes found.",
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
              return CheckboxListTile(
                dense: true,
                title: Text(doc["name"]),
                value: selectedClassIds.contains(doc.id),
                activeColor: primaryBlue,
                onChanged: (val) {
                  setState(() {
                    val == true
                        ? selectedClassIds.add(doc.id)
                        : selectedClassIds.remove(doc.id);
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
  // LOGIC (Auto-Generate IDs)
  // ==================================================

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Helper to turn "Computer Science" -> "COMPUTER_SCIENCE"
  String _generateId(String input) {
    return input.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '_');
  }

  Future<void> _addDepartment() async {
    final name = _deptNameController.text.trim();
    if (name.isEmpty) return _showSnack("Enter Name");

    setState(() => isLoading = true);
    final id = _generateId(name); // Auto-ID

    final docRef = FirebaseFirestore.instance.collection("departments").doc(id);
    if ((await docRef.get()).exists) {
      setState(() => isLoading = false);
      return _showSnack("Department '$name' already exists!");
    }

    await docRef.set({
      "name": name,
      "created_at": FieldValue.serverTimestamp(),
    });
    _deptNameController.clear();
    setState(() => isLoading = false);
    _showSnack("Department Added!");
  }

  Future<void> _addClass() async {
    if (selectedDeptId == null || selectedCourseType == null)
      return _showSnack("Select options first");
    final name = _classNameController.text.trim();
    if (name.isEmpty) return _showSnack("Enter Class Name");

    setState(() => isLoading = true);
    // Auto-ID: "DEPT_ID-CLASSNAME" to ensure uniqueness
    final id = "${selectedDeptId}_${_generateId(name)}";

    final docRef = FirebaseFirestore.instance.collection("classes").doc(id);
    if ((await docRef.get()).exists) {
      setState(() => isLoading = false);
      return _showSnack("Class already exists!");
    }

    await docRef.set({
      "name": name,
      "departmentId": selectedDeptId,
      "type": selectedCourseType,
      "created_at": FieldValue.serverTimestamp(),
    });

    _classNameController.clear();
    setState(() => isLoading = false);
    _showSnack("Class Added!");
  }

  Future<void> _addSubject() async {
    if (selectedDeptId == null ||
        selectedCourseType == null ||
        selectedSemester == null) {
      return _showSnack("Select all dropdowns");
    }
    final code = _subjectCodeController.text.trim().toUpperCase();
    final name = _subjectNameController.text.trim();

    if (code.isEmpty || name.isEmpty) return _showSnack("Enter Code and Name");
    if (selectedClassIds.isEmpty)
      return _showSnack("Select at least one class");

    setState(() => isLoading = true);
    // Subject Code is the ID (e.g. "CS101")
    final docRef = FirebaseFirestore.instance.collection("subjects").doc(code);

    if ((await docRef.get()).exists) {
      setState(() => isLoading = false);
      return _showSnack("Subject Code '$code' already exists!");
    }

    await docRef.set({
      "name": name,
      "departmentId": selectedDeptId,
      "type": selectedCourseType,
      "semester": selectedSemester,
      "classIds": selectedClassIds,
      "created_at": FieldValue.serverTimestamp(),
    });

    _subjectCodeController.clear();
    _subjectNameController.clear();
    selectedClassIds.clear();
    setState(() => isLoading = false);
    _showSnack("Subject Added!");
  }
}

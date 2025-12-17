import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminClassSubjectPage extends StatefulWidget {
  const AdminClassSubjectPage({super.key});

  @override
  State<AdminClassSubjectPage> createState() => _AdminClassSubjectPageState();
}

class _AdminClassSubjectPageState extends State<AdminClassSubjectPage> {
  // ---------------- CONTROLLERS ----------------
  // Department
  final _deptNameController = TextEditingController();
  final _deptIdController = TextEditingController(); // e.g. "CSE", "MECH"

  // Class
  final _classNameController = TextEditingController();
  final _classIdController = TextEditingController(); // e.g. "CSE-2025"

  // Subject
  final _subjectNameController = TextEditingController();
  final _subjectCodeController = TextEditingController(); // e.g. "CS101"

  // ---------------- SELECTIONS ----------------
  String? selectedDeptId;
  String? selectedCourseType; // "UG" or "PG"
  String? selectedSemester; // "Semester 1", "Semester 2"...

  // Stores list of Class IDs now, not names
  List<String> selectedClassIds = [];

  bool isLoading = false;
  static const Color primaryBlue = Color(0xFF2196F3);

  // ---------------- STATIC DATA ----------------
  final List<String> courseTypes = ["UG", "PG"];

  List<String> get currentSemesterList {
    if (selectedCourseType == "UG") {
      return List.generate(
        8,
        (index) => "Semester ${index + 1}",
      ); // Updated to standard 8
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
                        _deptIdController,
                        "Department ID (Unique code e.g. CSE)",
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        _deptNameController,
                        "Department Name (e.g. Computer Science)",
                      ),
                      const SizedBox(height: 12),
                      _saveButton("Save Department", _addDepartment),
                    ],
                  ),

                  // 2. ADD CLASS (YEAR)
                  _buildCard(
                    title: "2. Add Class / Section",
                    children: [
                      _departmentDropdown(),
                      const SizedBox(height: 12),
                      _ugPgDropdown(isForClass: true),
                      const SizedBox(height: 12),
                      _textField(
                        _classIdController,
                        "Class ID (Unique e.g. CS-A-2025)",
                      ),
                      const SizedBox(height: 12),
                      _textField(
                        _classNameController,
                        "Class Name (e.g. CS - Section A)",
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
                              "Sub Code (CS101)",
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
                        "Select Classes attending this Subject:",
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
  // WIDGET HELPERS (NO CHANGES TO STYLE)
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
            // Value is the ID (e.g., "CSE"), Child is the Name
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
              final className = doc["name"];
              final classId = doc.id; // Using the ID

              return CheckboxListTile(
                dense: true,
                title: Text(className), // Show Name
                subtitle: Text(
                  classId,
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ), // Show ID small
                value: selectedClassIds.contains(classId),
                activeColor: primaryBlue,
                onChanged: (val) {
                  setState(() {
                    val == true
                        ? selectedClassIds.add(classId)
                        : selectedClassIds.remove(classId);
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
  // FIRESTORE LOGIC (Using Manual IDs)
  // ==================================================

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addDepartment() async {
    final id = _deptIdController.text
        .trim()
        .toUpperCase(); // Force Upper e.g. "CSE"
    final name = _deptNameController.text.trim();

    if (id.isEmpty || name.isEmpty) return _showSnack("Enter ID and Name");

    setState(() => isLoading = true);

    // Use .doc(id).set(...) to create custom ID
    final docRef = FirebaseFirestore.instance.collection("departments").doc(id);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      setState(() => isLoading = false);
      return _showSnack("Department ID '$id' already exists!");
    }

    await docRef.set({
      "name": name,
      "created_at": FieldValue.serverTimestamp(),
    });

    _deptIdController.clear();
    _deptNameController.clear();
    setState(() => isLoading = false);
    _showSnack("Department Added!");
  }

  Future<void> _addClass() async {
    if (selectedDeptId == null || selectedCourseType == null) {
      return _showSnack("Select Department and UG/PG");
    }
    final id = _classIdController.text.trim().toUpperCase();
    final name = _classNameController.text.trim();

    if (id.isEmpty || name.isEmpty) {
      return _showSnack("Enter Class ID and Name");
    }

    setState(() => isLoading = true);

    final docRef = FirebaseFirestore.instance.collection("classes").doc(id);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      setState(() => isLoading = false);
      return _showSnack("Class ID '$id' already exists!");
    }

    await docRef.set({
      "name": name,
      "departmentId": selectedDeptId, // Links to Dept ID
      "type": selectedCourseType,
      "created_at": FieldValue.serverTimestamp(),
    });

    _classIdController.clear();
    _classNameController.clear();
    setState(() => isLoading = false);
    _showSnack("Class Added!");
  }

  Future<void> _addSubject() async {
    if (selectedDeptId == null ||
        selectedCourseType == null ||
        selectedSemester == null) {
      return _showSnack("Select Dept, UG/PG and Semester");
    }
    final code = _subjectCodeController.text.trim().toUpperCase();
    final name = _subjectNameController.text.trim();

    if (code.isEmpty || name.isEmpty) return _showSnack("Enter Code and Name");
    if (selectedClassIds.isEmpty) {
      return _showSnack("Select at least one class");
    }

    setState(() => isLoading = true);

    final docRef = FirebaseFirestore.instance.collection("subjects").doc(code);
    final docSnap = await docRef.get();

    if (docSnap.exists) {
      setState(() => isLoading = false);
      return _showSnack("Subject Code '$code' already exists!");
    }

    await docRef.set({
      "name": name,
      "departmentId": selectedDeptId,
      "type": selectedCourseType,
      "semester": selectedSemester,
      "classIds": selectedClassIds, // Storing IDs now
      "created_at": FieldValue.serverTimestamp(),
    });

    _subjectCodeController.clear();
    _subjectNameController.clear();
    selectedClassIds.clear();
    setState(() => isLoading = false);
    _showSnack("Subject Added!");
  }
}

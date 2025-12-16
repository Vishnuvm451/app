import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminClassSubjectPage extends StatefulWidget {
  const AdminClassSubjectPage({super.key});

  @override
  State<AdminClassSubjectPage> createState() => _AdminClassSubjectPageState();
}

class _AdminClassSubjectPageState extends State<AdminClassSubjectPage> {
  final _deptController = TextEditingController();
  final _classController = TextEditingController();
  final _subjectController = TextEditingController();

  String? selectedDepartmentId;
  List<String> selectedSubjectClasses = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Departments • Classes • Subjects"),
        backgroundColor: Colors.blue.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle("Add Department"),
            _textField(_deptController, "Department name"),
            _saveButton("Save Department", _addDepartment),

            const Divider(height: 40),

            _sectionTitle("Add Class"),
            _departmentDropdown(),
            _textField(_classController, "Class name (CS2, CS3...)"),
            _saveButton("Save Class", _addClass),

            const Divider(height: 40),

            _sectionTitle("Add Subject"),
            _departmentDropdown(),
            _textField(_subjectController, "Subject name"),
            _classMultiSelect(),
            _saveButton("Save Subject", _addSubject),
          ],
        ),
      ),
    );
  }

  // ---------------- UI HELPERS ----------------

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _textField(TextEditingController c, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
          backgroundColor: Colors.blue.shade800,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(text),
      ),
    );
  }

  // ---------------- DROPDOWNS ----------------

  Widget _departmentDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("departments").snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        return DropdownButtonFormField<String>(
          value: selectedDepartmentId,
          hint: const Text("Select Department"),
          items: snapshot.data!.docs.map((doc) {
            return DropdownMenuItem(value: doc.id, child: Text(doc["name"]));
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedDepartmentId = val;
              selectedSubjectClasses.clear();
            });
          },
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      },
    );
  }

  Widget _classMultiSelect() {
    if (selectedDepartmentId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("classes")
          .where("departmentId", isEqualTo: selectedDepartmentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        return Column(
          children: snapshot.data!.docs.map((doc) {
            return CheckboxListTile(
              title: Text(doc["name"]),
              value: selectedSubjectClasses.contains(doc["name"]),
              onChanged: (val) {
                setState(() {
                  val == true
                      ? selectedSubjectClasses.add(doc["name"])
                      : selectedSubjectClasses.remove(doc["name"]);
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  // ---------------- FIRESTORE ACTIONS ----------------

  Future<void> _addDepartment() async {
    await FirebaseFirestore.instance.collection("departments").add({
      "name": _deptController.text.trim(),
      "active": true,
    });
    _deptController.clear();
  }

  Future<void> _addClass() async {
    if (selectedDepartmentId == null) return;

    await FirebaseFirestore.instance.collection("classes").add({
      "name": _classController.text.trim(),
      "departmentId": selectedDepartmentId,
      "active": true,
    });
    _classController.clear();
  }

  Future<void> _addSubject() async {
    if (selectedDepartmentId == null || selectedSubjectClasses.isEmpty) return;

    await FirebaseFirestore.instance.collection("subjects").add({
      "name": _subjectController.text.trim(),
      "departmentId": selectedDepartmentId,
      "classes": selectedSubjectClasses,
      "active": true,
    });

    _subjectController.clear();
    selectedSubjectClasses.clear();
    setState(() {});
  }
}

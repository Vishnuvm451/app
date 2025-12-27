import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminClassSubjectPage extends StatefulWidget {
  const AdminClassSubjectPage({super.key});

  @override
  State<AdminClassSubjectPage> createState() => _AdminClassSubjectPageState();
}

class _AdminClassSubjectPageState extends State<AdminClassSubjectPage> {
  // ================= CONTROLLERS =================
  final _deptIdCtrl = TextEditingController();
  final _deptNameCtrl = TextEditingController();
  final _classNameCtrl = TextEditingController();
  final _subjectNameCtrl = TextEditingController();

  // ================= STATE =================
  String? selectedDepartmentId;
  String? selectedClassId;
  String? courseType;
  int? year;
  int? semester; // ✅ CORRECT VARIABLE

  final List<String> courseTypes = ['UG', 'PG'];
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ======================================================
  // ADD DEPARTMENT
  // ======================================================
  Future<void> addDepartment() async {
    if (_deptIdCtrl.text.isEmpty || _deptNameCtrl.text.isEmpty) {
      _showSnack("Enter department ID and name");
      return;
    }

    final id = _deptIdCtrl.text.trim().toUpperCase();

    await _db.collection('departments').doc(id).set({
      'id': id,
      'name': _deptNameCtrl.text.trim(),
      'created_at': FieldValue.serverTimestamp(),
    });

    _deptIdCtrl.clear();
    _deptNameCtrl.clear();
    _showSnack("Department added", success: true);
  }

  // ======================================================
  // ADD CLASS + AUTO SEMESTERS
  // ======================================================
  Future<void> addClass() async {
    if (selectedDepartmentId == null ||
        _classNameCtrl.text.isEmpty ||
        courseType == null ||
        year == null) {
      _showSnack("Fill all class fields");
      return;
    }

    final classId = "${selectedDepartmentId}_${courseType}_YEAR$year";

    await _db.collection('classes').doc(classId).set({
      'id': classId,
      'name': _classNameCtrl.text.trim(),
      'departmentId': selectedDepartmentId,
      'courseType': courseType,
      'year': year,
      'created_at': FieldValue.serverTimestamp(),
    });

    await _autoCreateSemesters(classId, courseType!);

    _classNameCtrl.clear();
    _showSnack("Class added", success: true);
  }

  // ======================================================
  // AUTO CREATE SEMESTERS
  // ======================================================
  Future<void> _autoCreateSemesters(String classId, String courseType) async {
    final totalSemesters = courseType == 'PG' ? 4 : 8;

    for (int i = 1; i <= totalSemesters; i++) {
      await _db.collection('semesters').doc("${classId}_SEM$i").set({
        'id': "${classId}_SEM$i",
        'classId': classId,
        'semester': i,
        'created_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ======================================================
  // ADD SUBJECT
  // ======================================================
  Future<void> addSubject() async {
    if (selectedClassId == null ||
        semester == null ||
        _subjectNameCtrl.text.isEmpty)
      return;

    final id =
        "${selectedClassId}_SEM${semester}_${_subjectNameCtrl.text.trim()}";

    await _db.collection('subjects').doc(id).set({
      'id': id,
      'name': _subjectNameCtrl.text.trim(),
      'classId': selectedClassId,
      'semester': semester,
      'created_at': FieldValue.serverTimestamp(),
    });

    _subjectNameCtrl.clear();
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Academic Setup")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section("Add Department"),
          _field(_deptIdCtrl, "Department ID (CSE)"),
          _field(_deptNameCtrl, "Department Name"),
          _button("Add Department", addDepartment),

          const Divider(height: 40),

          _section("Add Class"),
          _departmentDropdown(),
          _field(_classNameCtrl, "Class Name"),
          _courseDropdown(),
          _yearDropdown(),
          _button("Add Class", addClass),

          const Divider(height: 40),

          _section("Add Subject"),
          _classDropdown(),
          _semesterDropdown(),
          _field(_subjectNameCtrl, "Subject Name"),
          _button("Add Subject", addSubject),
        ],
      ),
    );
  }

  // ======================================================
  // WIDGET HELPERS
  // ======================================================
  Widget _field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
        ).copyWith(labelText: label),
      ),
    );
  }

  Widget _button(String text, VoidCallback fn) {
    return ElevatedButton(onPressed: fn, child: Text(text));
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  // ======================================================
  // DROPDOWNS
  // ======================================================
  Widget _departmentDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('departments').snapshots(),
      builder: (_, s) {
        if (!s.hasData) return const SizedBox();
        return DropdownButtonFormField<String>(
          hint: const Text("Select Department"),
          value: selectedDepartmentId,
          items: s.data!.docs
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d['name'])))
              .toList(),
          onChanged: (v) {
            setState(() {
              selectedDepartmentId = v;
              selectedClassId = null;
            });
          },
        );
      },
    );
  }

  Widget _classDropdown() {
    if (selectedDepartmentId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('classes')
          .where('departmentId', isEqualTo: selectedDepartmentId)
          .snapshots(),
      builder: (_, s) {
        if (!s.hasData) return const SizedBox();
        return DropdownButtonFormField<String>(
          hint: const Text("Select Class"),
          value: selectedClassId,
          items: s.data!.docs
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c['name'])))
              .toList(),
          onChanged: (v) => setState(() => selectedClassId = v),
        );
      },
    );
  }

  Widget _courseDropdown() {
    return DropdownButtonFormField<String>(
      hint: const Text("Course Type"),
      value: courseType,
      items: courseTypes
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (v) => setState(() => courseType = v),
    );
  }

  Widget _yearDropdown() {
    final years = courseType == 'PG' ? [1, 2] : [1, 2, 3, 4];
    return DropdownButtonFormField<int>(
      hint: const Text("Year"),
      value: year,
      items: years
          .map((y) => DropdownMenuItem(value: y, child: Text("Year $y")))
          .toList(),
      onChanged: (v) => setState(() => year = v),
    );
  }

  Widget _semesterDropdown() {
    final semesters = courseType == 'PG'
        ? [1, 2, 3, 4]
        : [1, 2, 3, 4, 5, 6, 7, 8];

    return DropdownButtonFormField<int>(
      hint: const Text("Semester"),
      value: semester,
      items: semesters
          .map((s) => DropdownMenuItem(value: s, child: Text("Semester $s")))
          .toList(),
      onChanged: (v) => setState(() => semester = v),
    );
  }
}

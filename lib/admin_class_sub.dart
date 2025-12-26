import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminClassSubjectPage extends StatefulWidget {
  const AdminClassSubjectPage({super.key});

  @override
  State<AdminClassSubjectPage> createState() => _AdminClassSubjectPageState();
}

class _AdminClassSubjectPageState extends State<AdminClassSubjectPage> {
  // ---------------- CONTROLLERS ----------------
  final _deptIdCtrl = TextEditingController();
  final _deptNameCtrl = TextEditingController();
  final _classNameCtrl = TextEditingController();

  // ---------------- STATE ----------------
  String? selectedDepartmentId;
  String? courseType;
  int? year;

  final List<String> courseTypes = ['UG', 'PG'];

  // ---------------- FIRESTORE ----------------
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ======================================================
  // ADD DEPARTMENT (ROOT LEVEL)
  // ======================================================
  Future<void> _addDepartment() async {
    if (_deptIdCtrl.text.isEmpty || _deptNameCtrl.text.isEmpty) {
      _showSnack("Enter department ID & name");
      return;
    }

    final deptId = _deptIdCtrl.text.trim().toUpperCase();

    await _db.collection('departments').doc(deptId).set({
      'id': deptId,
      'name': _deptNameCtrl.text.trim(),
      'created_at': FieldValue.serverTimestamp(),
    });

    _deptIdCtrl.clear();
    _deptNameCtrl.clear();

    _showSnack("Department added", success: true);
  }

  // ======================================================
  // ADD CLASS (UNDER DEPARTMENT)
  // ======================================================
  Future<void> _addClass() async {
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

    _classNameCtrl.clear();
    courseType = null;
    year = null;

    setState(() {});
    _showSnack("Class added", success: true);
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Classes & Departments")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle("Add Department"),
          _textField(_deptIdCtrl, "Department ID (CSE)"),
          _textField(_deptNameCtrl, "Department Name"),
          _primaryButton("Add Department", _addDepartment),

          const Divider(height: 40),

          _sectionTitle("Add Class"),
          _departmentDropdown(),
          _textField(_classNameCtrl, "Class Name (A / B / 1st Year)"),
          _courseDropdown(),
          _yearDropdown(),
          _primaryButton("Add Class", _addClass),

          const Divider(height: 40),

          _sectionTitle("Existing Classes"),
          _existingClassesList(),
        ],
      ),
    );
  }

  // ======================================================
  // WIDGETS
  // ======================================================
  Widget _departmentDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('departments').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Text(
            "No departments found. Add a department first.",
            style: TextStyle(color: Colors.red),
          );
        }

        return DropdownButtonFormField<String>(
          value: selectedDepartmentId,
          hint: const Text("Select Department"),
          items: docs
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d['name'])))
              .toList(),
          onChanged: (val) {
            setState(() => selectedDepartmentId = val);
          },
        );
      },
    );
  }

  Widget _courseDropdown() {
    return DropdownButtonFormField<String>(
      value: courseType,
      hint: const Text("Course Type"),
      items: courseTypes
          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
          .toList(),
      onChanged: (val) => setState(() => courseType = val),
    );
  }

  Widget _yearDropdown() {
    final years = courseType == 'PG' ? [1, 2] : [1, 2, 3, 4];

    return DropdownButtonFormField<int>(
      value: year,
      hint: const Text("Year"),
      items: years
          .map((y) => DropdownMenuItem(value: y, child: Text("Year $y")))
          .toList(),
      onChanged: (val) => setState(() => year = val),
    );
  }

  Widget _existingClassesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('classes').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        if (snapshot.data!.docs.isEmpty) {
          return const Text("No classes added yet");
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return ListTile(
              title: Text(data['name']),
              subtitle: Text(
                "${data['departmentId']} | ${data['courseType']} | Year ${data['year']}",
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ======================================================
  // HELPERS
  // ======================================================
  Widget _textField(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _primaryButton(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(onPressed: onTap, child: Text(text)),
    );
  }

  Widget _sectionTitle(String text) {
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
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class AdminAcademicSetupPage extends StatefulWidget {
  const AdminAcademicSetupPage({super.key});

  @override
  State<AdminAcademicSetupPage> createState() => _AdminAcademicSetupPageState();
}

class _AdminAcademicSetupPageState extends State<AdminAcademicSetupPage> {
  // ---------------- THEME ----------------
  final Color primaryBlue = const Color(0xFF2196F3);

  // ---------------- CONTROLLERS ----------------
  final TextEditingController _deptNameCtrl = TextEditingController();
  final TextEditingController _subjectCtrl = TextEditingController();

  // ---------------- STATE VARIABLES ----------------
  bool isLoading = false;

  // For Class Creation
  String? selectedDeptIdForClass;
  String? courseTypeForClass; // UG / PG
  int? yearForClass; // 1-4

  // For Subject Creation
  String? selectedDeptIdForSubject;
  String? selectedClassIdForSubject;

  // 🔥 NEW: Store the Year of the selected class to filter semesters
  int? selectedClassYear;
  String? selectedClassCourseType;

  int? semesterForSubject;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ======================================================
  // 1. ADD DEPARTMENT
  // ======================================================
  Future<void> addDepartment() async {
    final name = _deptNameCtrl.text.trim();
    if (name.isEmpty) return _showSnack("Enter department name", error: true);

    setState(() => isLoading = true);

    final id = name.toUpperCase().replaceAll(RegExp(r'\s+'), '_');

    try {
      final doc = await _db.collection('department').doc(id).get();
      if (doc.exists) throw "Department already exists";

      await _db.collection('department').doc(id).set({
        'id': id,
        'name': name,
        'created_at': FieldValue.serverTimestamp(),
      });

      _deptNameCtrl.clear();
      _showSnack("Department '$name' added!");
    } catch (e) {
      _showSnack(e.toString(), error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ======================================================
  // 2. ADD CLASS
  // ======================================================
  Future<void> addClass() async {
    if (selectedDeptIdForClass == null ||
        courseTypeForClass == null ||
        yearForClass == null) {
      return _showSnack("Please select all dropdowns", error: true);
    }

    setState(() => isLoading = true);

    try {
      final classId =
          "${selectedDeptIdForClass}_${courseTypeForClass}_YEAR$yearForClass";
      final displayName = "$courseTypeForClass Year $yearForClass";

      await _db.collection('class').doc(classId).set({
        'id': classId,
        'name': displayName,
        'departmentId': selectedDeptIdForClass,
        'courseType': courseTypeForClass,
        'year': yearForClass,
        'created_at': FieldValue.serverTimestamp(),
      });

      _showSnack("Class '$displayName' added!");
    } catch (e) {
      _showSnack("Error: $e", error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ======================================================
  // 3. ADD SUBJECT
  // ======================================================
  Future<void> addSubject() async {
    if (selectedClassIdForSubject == null ||
        semesterForSubject == null ||
        _subjectCtrl.text.trim().isEmpty) {
      return _showSnack("Please fill all subject fields", error: true);
    }

    setState(() => isLoading = true);

    try {
      final subjectName = _subjectCtrl.text.trim();
      final cleanSubName = subjectName.toUpperCase().replaceAll(
        RegExp(r'\s+'),
        '_',
      );
      final subjectId =
          "${selectedClassIdForSubject}_SEM${semesterForSubject}_$cleanSubName";

      await _db.collection('subject').doc(subjectId).set({
        'id': subjectId,
        'name': subjectName,
        'classId': selectedClassIdForSubject,
        'departmentId': selectedDeptIdForSubject,
        'semester': "Semester $semesterForSubject",
        'type': selectedClassCourseType,
        'created_at': FieldValue.serverTimestamp(),
      });

      _subjectCtrl.clear();
      _showSnack("Subject '$subjectName' added!");
    } catch (e) {
      _showSnack("Error: $e", error: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ======================================================
  // UI BUILD
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Academic Setup"),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. DEPARTMENT
              _buildSectionCard(
                title: "1. Add Department",
                icon: Icons.account_balance,
                children: [
                  _buildTextField(
                    controller: _deptNameCtrl,
                    label: "Department Name (e.g. Computer Science)",
                    icon: Icons.edit,
                  ),
                  const SizedBox(height: 16),
                  _buildButton("SAVE DEPARTMENT", addDepartment),
                ],
              ),

              // 2. CLASS
              _buildSectionCard(
                title: "2. Add Class",
                icon: Icons.class_,
                children: [
                  _buildDeptDropdown(
                    value: selectedDeptIdForClass,
                    onChanged: (val) =>
                        setState(() => selectedDeptIdForClass = val),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          value: courseTypeForClass,
                          hint: "Type",
                          items: ["UG", "PG"],
                          onChanged: (val) => setState(() {
                            courseTypeForClass = val;
                            yearForClass = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildYearDropdown()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildButton("SAVE CLASS", addClass),
                ],
              ),

              // 3. SUBJECT
              _buildSectionCard(
                title: "3. Add Subject",
                icon: Icons.menu_book,
                children: [
                  _buildDeptDropdown(
                    value: selectedDeptIdForSubject,
                    onChanged: (val) => setState(() {
                      selectedDeptIdForSubject = val;
                      selectedClassIdForSubject = null;
                      selectedClassCourseType = null;
                      selectedClassYear = null; // Reset Year
                      semesterForSubject = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _buildClassDropdownForSubject(),
                  const SizedBox(height: 12),
                  _buildSemesterDropdown(), // 🔥 UPDATED LOGIC HERE
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _subjectCtrl,
                    label: "Subject Name",
                    icon: Icons.book,
                  ),
                  const SizedBox(height: 16),
                  _buildButton("SAVE SUBJECT", addSubject),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // ======================================================
  // WIDGET HELPERS
  // ======================================================
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryBlue, size: 28),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    List<TextInputFormatter>? formatter,
  }) {
    return TextField(
      controller: controller,
      inputFormatters: formatter,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ---------- DROPDOWNS ----------
  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDeptDropdown({
    required String? value,
    required Function(String?) onChanged,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('department').orderBy('name').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            labelText: "Select Department",
            prefixIcon: const Icon(Icons.account_balance),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: snapshot.data!.docs.map((doc) {
            return DropdownMenuItem(value: doc.id, child: Text(doc['name']));
          }).toList(),
          onChanged: onChanged,
        );
      },
    );
  }

  Widget _buildYearDropdown() {
    final List<int> years = (courseTypeForClass == 'PG')
        ? [1, 2]
        : [1, 2, 3, 4];
    return DropdownButtonFormField<int>(
      value: yearForClass,
      decoration: InputDecoration(
        labelText: "Year",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: years
          .map((y) => DropdownMenuItem(value: y, child: Text("Year $y")))
          .toList(),
      onChanged: (val) => setState(() => yearForClass = val),
    );
  }

  Widget _buildClassDropdownForSubject() {
    if (selectedDeptIdForSubject == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Text(
            "Select Department first",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('class')
          .where('departmentId', isEqualTo: selectedDeptIdForSubject)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();

        final docs = snapshot.data!.docs;
        if (docs.isEmpty)
          return const Text("No classes found in this department");

        return DropdownButtonFormField<String>(
          value: selectedClassIdForSubject,
          decoration: InputDecoration(
            labelText: "Select Class",
            prefixIcon: const Icon(Icons.class_),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: docs.map((doc) {
            return DropdownMenuItem(
              value: doc.id,
              child: Text(doc['name']),
              onTap: () {
                // 🔥 Capture YEAR and COURSE TYPE to filter semesters
                setState(() {
                  selectedClassCourseType = doc['courseType'];
                  selectedClassYear = doc['year']; // Gets year (e.g., 3)
                });
              },
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              selectedClassIdForSubject = val;
              semesterForSubject = null;
            });
          },
        );
      },
    );
  }

  // 🔥 UPDATED SEMESTER LOGIC
  Widget _buildSemesterDropdown() {
    if (selectedClassIdForSubject == null || selectedClassYear == null) {
      return const SizedBox();
    }

    // Calculation: Year 1 -> Sem 1,2 | Year 2 -> Sem 3,4 | Year 3 -> Sem 5,6
    final int startSem = (selectedClassYear! * 2) - 1;
    final int endSem = selectedClassYear! * 2;
    final List<int> semesters = [startSem, endSem];

    return DropdownButtonFormField<int>(
      value: semesterForSubject,
      decoration: InputDecoration(
        labelText: "Semester",
        prefixIcon: const Icon(Icons.calendar_view_day),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: semesters
          .map((s) => DropdownMenuItem(value: s, child: Text("Semester $s")))
          .toList(),
      onChanged: (val) => setState(() => semesterForSubject = val),
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

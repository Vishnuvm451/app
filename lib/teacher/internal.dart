import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddInternalMarksPage extends StatefulWidget {
  final String? classId;
  final String? subjectId;

  const AddInternalMarksPage({super.key, this.classId, this.subjectId});

  @override
  State<AddInternalMarksPage> createState() => _AddInternalMarksPageState();
}

// Helper class to hold controllers for each student row
class StudentControllers {
  final TextEditingController internal = TextEditingController();
  final TextEditingController attendance = TextEditingController();
  final TextEditingController assignment = TextEditingController();
}

class _AddInternalMarksPageState extends State<AddInternalMarksPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Color primaryBlue = const Color(0xFF2196F3);

  // ---------------- STATE ----------------
  String? departmentId;
  String? selectedClassId;
  int? selectedSemester;
  String? selectedSubjectId;

  bool isLoadingProfile = true;
  bool isSaving = false;
  bool isLoadingExisting = false;

  // Mark Config
  final TextEditingController _testNameCtrl = TextEditingController();
  final TextEditingController _maxInternalCtrl = TextEditingController(
    text: '50',
  );
  final TextEditingController _maxAttendanceCtrl = TextEditingController(
    text: '5',
  );
  final TextEditingController _maxAssignmentCtrl = TextEditingController(
    text: '5',
  );

  // Map to store controllers for each student ID
  final Map<String, StudentControllers> _studentControllers = {};

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  @override
  void dispose() {
    _testNameCtrl.dispose();
    _maxInternalCtrl.dispose();
    _maxAttendanceCtrl.dispose();
    _maxAssignmentCtrl.dispose();
    for (var ctrl in _studentControllers.values) {
      ctrl.internal.dispose();
      ctrl.attendance.dispose();
      ctrl.assignment.dispose();
    }
    super.dispose();
  }

  // ===================================================
  // 1. LOAD TEACHER PROFILE
  // ===================================================
  Future<void> _loadTeacherProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await _db.collection('teacher').doc(user.uid).get();
      if (!snap.exists) return;
      final data = snap.data()!;

      if (mounted) {
        setState(() {
          departmentId = data['departmentId'];
          // If widget passed a classId, use it, otherwise use teacher's default
          selectedClassId = widget.classId ?? data['classId'];
          isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingProfile = false);
    }
  }

  // ===================================================
  // 2. LOAD EXISTING MARKS (For Editing)
  // ===================================================
  Future<void> _loadExistingMarks(String testName) async {
    if (testName.trim().isEmpty ||
        selectedClassId == null ||
        selectedSubjectId == null)
      return;

    setState(() => isLoadingExisting = true);

    // Unique ID for this test session
    final docId = '${selectedClassId}_${selectedSubjectId}_${testName.trim()}';

    try {
      final ref = _db.collection('internal_mark').doc(docId);
      final snap = await ref.get();

      if (!snap.exists) {
        _clearAllFields(); // New test, clear inputs
      } else {
        // Load Config
        final data = snap.data()!;
        _maxInternalCtrl.text = (data['maxMarks']['internal'] ?? 50).toString();
        _maxAttendanceCtrl.text = (data['maxMarks']['attendance'] ?? 5)
            .toString();
        _maxAssignmentCtrl.text = (data['maxMarks']['assignment'] ?? 5)
            .toString();

        // Load Student Marks
        final studentsSnap = await ref.collection('student').get();
        for (var doc in studentsSnap.docs) {
          final sid = doc.id;
          final sData = doc.data();

          // Ensure controller exists
          _studentControllers.putIfAbsent(sid, () => StudentControllers());

          _studentControllers[sid]!.internal.text = (sData['internal'] ?? '')
              .toString();
          _studentControllers[sid]!.attendance.text =
              (sData['attendance'] ?? '').toString();
          _studentControllers[sid]!.assignment.text =
              (sData['assignment'] ?? '').toString();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Loaded existing marks for $testName")),
        );
      }
    } catch (e) {
      debugPrint("Error loading marks: $e");
    } finally {
      if (mounted) setState(() => isLoadingExisting = false);
    }
  }

  void _clearAllFields() {
    for (var ctrl in _studentControllers.values) {
      ctrl.internal.clear();
      ctrl.attendance.clear();
      ctrl.assignment.clear();
    }
  }

  // ===================================================
  // 3. SAVE MARKS LOGIC
  // ===================================================
  Future<void> _saveMarks() async {
    final testName = _testNameCtrl.text.trim();
    if (testName.isEmpty ||
        selectedClassId == null ||
        selectedSubjectId == null) {
      _showSnack("Please select class, subject and enter test name");
      return;
    }

    final maxInt = double.tryParse(_maxInternalCtrl.text) ?? 50;
    final maxAtt = double.tryParse(_maxAttendanceCtrl.text) ?? 5;
    final maxAss = double.tryParse(_maxAssignmentCtrl.text) ?? 5;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    final docId = '${selectedClassId}_${selectedSubjectId}_$testName';
    final batch = _db.batch();
    final mainRef = _db.collection('internal_mark').doc(docId);

    // 1. Save Parent Document (Test Metadata)
    batch.set(mainRef, {
      'classId': selectedClassId,
      'subjectId': selectedSubjectId,
      'testName': testName,
      'maxMarks': {
        'internal': maxInt,
        'attendance': maxAtt,
        'assignment': maxAss,
        'total': maxInt + maxAtt + maxAss,
      },
      'updatedBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Loop through students and save their marks
    _studentControllers.forEach((studentId, ctrls) {
      final internalStr = ctrls.internal.text.trim();
      final attendanceStr = ctrls.attendance.text.trim();
      final assignmentStr = ctrls.assignment.text.trim();

      // Only save if at least one field is filled
      if (internalStr.isNotEmpty ||
          attendanceStr.isNotEmpty ||
          assignmentStr.isNotEmpty) {
        final internal = double.tryParse(internalStr) ?? 0;
        final attendance = double.tryParse(attendanceStr) ?? 0;
        final assignment = double.tryParse(assignmentStr) ?? 0;

        batch.set(mainRef.collection('student').doc(studentId), {
          'studentId': studentId,
          'internal': internal,
          'attendance': attendance,
          'assignment': assignment,
          'total': internal + attendance + assignment, // Auto calculate total
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });

    try {
      await batch.commit();
      _showSnack("Marks saved successfully!", success: true);
    } catch (e) {
      _showSnack("Failed to save marks: $e");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ===================================================
  // UI BUILD
  // ===================================================
  @override
  Widget build(BuildContext context) {
    if (isLoadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Internal Marks",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. SELECTION CARD (Class -> Sem -> Subject)
          _selectionCard(),

          // 2. MARKING AREA
          Expanded(
            child: selectedSubjectId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.class_outlined,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Select Class, Sem & Subject",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      _configCard(), // Test Name & Max Marks
                      Expanded(child: _studentsList()), // Student Inputs
                      _saveButton(), // Save Button
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // SELECTION CARD
  // --------------------------------------------------
  Widget _selectionCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('class')
            .where('departmentId', isEqualTo: departmentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LinearProgressIndicator();

          final classes = snapshot.data!.docs;

          // Calculate available semesters based on selected class year
          List<int> availableSemesters = [];
          if (selectedClassId != null) {
            try {
              final selectedDoc = classes.firstWhere(
                (d) => d.id == selectedClassId,
              );
              final classYear = (selectedDoc.data() as Map)['year'] ?? 1;
              availableSemesters = [(classYear * 2) - 1, (classYear * 2)];
            } catch (e) {
              availableSemesters = [1, 2]; // Fallback
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Class Dropdown
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: selectedClassId,
                      isExpanded: true,
                      decoration: _inputDecoration("Class"),
                      items: classes
                          .map(
                            (d) => DropdownMenuItem(
                              value: d.id,
                              child: Text(d['name']),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() {
                        selectedClassId = val;
                        selectedSemester = null;
                        selectedSubjectId = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Semester Dropdown
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<int>(
                      value: availableSemesters.contains(selectedSemester)
                          ? selectedSemester
                          : null,
                      decoration: _inputDecoration("Sem"),
                      items: availableSemesters
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text("Sem $s"),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() {
                        selectedSemester = val;
                        selectedSubjectId = null;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Subject Selection (Chips)
              if (selectedClassId != null && selectedSemester != null)
                SizedBox(
                  height: 40,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _db
                        .collection('subject')
                        .where('classId', isEqualTo: selectedClassId)
                        .where('semester', isEqualTo: selectedSemester)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Text("Loading...");
                      final subjects = snapshot.data!.docs;

                      if (subjects.isEmpty)
                        return const Text(
                          "No subjects found",
                          style: TextStyle(color: Colors.red),
                        );

                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: subjects.length,
                        itemBuilder: (ctx, i) {
                          final sub = subjects[i];
                          final isSelected = sub.id == selectedSubjectId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(sub['name']),
                              selected: isSelected,
                              selectedColor: primaryBlue.withOpacity(0.2),
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? primaryBlue
                                    : Colors.black87,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              onSelected: (bool selected) {
                                setState(
                                  () => selectedSubjectId = selected
                                      ? sub.id
                                      : null,
                                );
                                // Try loading marks if test name exists
                                if (selected && _testNameCtrl.text.isNotEmpty) {
                                  _loadExistingMarks(_testNameCtrl.text);
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // CONFIG CARD (Test Name & Max Marks)
  // --------------------------------------------------
  Widget _configCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          TextField(
            controller: _testNameCtrl,
            onSubmitted: _loadExistingMarks,
            decoration: InputDecoration(
              labelText: "Test Name (e.g., Internal 1)",
              hintText: "Enter & Press Enter to Load",
              prefixIcon: const Icon(Icons.edit_note),
              suffixIcon: isLoadingExisting
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () => _loadExistingMarks(_testNameCtrl.text),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _miniInput(_maxInternalCtrl, "Exam (50)"),
              const SizedBox(width: 8),
              _miniInput(_maxAttendanceCtrl, "Att (5)"),
              const SizedBox(width: 8),
              _miniInput(_maxAssignmentCtrl, "Assgn (5)"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniInput(TextEditingController ctrl, String label) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // STUDENT LIST
  // --------------------------------------------------
  Widget _studentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('student')
          .where('classId', isEqualTo: selectedClassId)
          .snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final students = snapshot.data!.docs;
        if (students.isEmpty)
          return const Center(child: Text("No students in this class"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (_, i) {
            final stu = students[i];
            final id = stu.id;
            final name = stu['name'] ?? 'Unknown';

            // Ensure controller exists for this student
            _studentControllers.putIfAbsent(id, () => StudentControllers());
            final ctrls = _studentControllers[id]!;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        // Dynamic Total Calculator
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            ctrls.internal,
                            ctrls.attendance,
                            ctrls.assignment,
                          ]),
                          builder: (context, _) {
                            double val =
                                (double.tryParse(ctrls.internal.text) ?? 0) +
                                (double.tryParse(ctrls.attendance.text) ?? 0) +
                                (double.tryParse(ctrls.assignment.text) ?? 0);
                            return Text(
                              "Total: ${val.toStringAsFixed(1)}",
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        _markInput(ctrls.internal, "Exam"),
                        const SizedBox(width: 8),
                        _markInput(ctrls.attendance, "Att."),
                        const SizedBox(width: 8),
                        _markInput(ctrls.assignment, "Assgn."),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _markInput(TextEditingController ctrl, String label) {
    return Expanded(
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // SAVE BUTTON
  // --------------------------------------------------
  Widget _saveButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: isSaving ? null : _saveMarks,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text(
                  "SAVE MARKS",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: const OutlineInputBorder(),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

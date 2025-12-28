import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddInternalMarksPage extends StatefulWidget {
  final String classId;
  final String subjectId;

  const AddInternalMarksPage({
    super.key,
    required this.classId,
    required this.subjectId,
  });

  @override
  State<AddInternalMarksPage> createState() => _AddInternalMarksPageState();
}

class _AddInternalMarksPageState extends State<AddInternalMarksPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final TextEditingController _testNameCtrl = TextEditingController();
  final TextEditingController _totalMarksCtrl = TextEditingController(
    text: '100',
  );

  bool isSaving = false;
  bool isLoadingExisting = false;

  /// studentId -> marks controller
  final Map<String, TextEditingController> marksControllers = {};

  // ===================================================
  // INIT — TEACHER ONLY ACCESS
  // ===================================================
  @override
  void initState() {
    super.initState();
    _checkTeacherAccess();
  }

  Future<void> _checkTeacherAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _denyAccess();
      return;
    }

    final roleSnap = await _db.collection('users').doc(user.uid).get();
    if (!roleSnap.exists || roleSnap['role'] != 'teacher') {
      _denyAccess();
    }
  }

  void _denyAccess() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Access denied: Teachers only"),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.pop(context);
  }

  // ===================================================
  // LOAD EXISTING MARKS (EDIT MODE)
  // ===================================================
  Future<void> _loadExistingMarks(String testName) async {
    if (testName.trim().isEmpty) return;

    setState(() => isLoadingExisting = true);

    final docId = '${widget.classId}_${widget.subjectId}_$testName';
    final ref = _db.collection('internal_marks').doc(docId);

    final snap = await ref.get();
    if (!snap.exists) {
      setState(() => isLoadingExisting = false);
      return;
    }

    final studentsSnap = await ref.collection('students').get();

    for (var doc in studentsSnap.docs) {
      marksControllers.putIfAbsent(doc.id, () => TextEditingController());
      marksControllers[doc.id]!.text = doc['marks'].toString();
    }

    setState(() => isLoadingExisting = false);
  }

  // ===================================================
  // SAVE / UPDATE MARKS
  // ===================================================
  Future<void> _saveMarks() async {
    if (_testNameCtrl.text.trim().isEmpty ||
        _totalMarksCtrl.text.trim().isEmpty) {
      _showSnack("Enter test name & total marks");
      return;
    }

    final totalMarks = int.tryParse(_totalMarksCtrl.text.trim());
    if (totalMarks == null || totalMarks <= 0) {
      _showSnack("Invalid total marks");
      return;
    }

    final teacherId = FirebaseAuth.instance.currentUser!.uid;
    final testName = _testNameCtrl.text.trim();

    final docId = '${widget.classId}_${widget.subjectId}_$testName';

    try {
      setState(() => isSaving = true);

      final batch = _db.batch();
      final mainRef = _db.collection('internal_marks').doc(docId);

      // -------- MAIN DOC --------
      batch.set(mainRef, {
        'classId': widget.classId,
        'subjectId': widget.subjectId,
        'testName': testName,
        'totalMarks': totalMarks,
        'updatedBy': teacherId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // -------- STUDENT MARKS --------
      marksControllers.forEach((studentId, ctrl) {
        if (ctrl.text.trim().isEmpty) return;

        final marks = int.tryParse(ctrl.text.trim());
        if (marks == null || marks < 0 || marks > totalMarks) return;

        final stuRef = mainRef.collection('students').doc(studentId);
        batch.set(stuRef, {
          'studentId': studentId,
          'marks': marks,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      await batch.commit();

      _showSnack("Internal marks saved / updated", success: true);
      Navigator.pop(context);
    } catch (e) {
      _showSnack("Failed to save marks");
    } finally {
      setState(() => isSaving = false);
    }
  }

  // ===================================================
  // UI
  // ===================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add / Edit Internal Marks"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _topForm(),
          const Divider(),
          Expanded(child: _studentsList()),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isSaving ? null : _saveMarks,
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "SAVE / UPDATE MARKS",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================
  // TOP FORM
  // ===================================================
  Widget _topForm() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _testNameCtrl,
            onSubmitted: _loadExistingMarks,
            decoration: const InputDecoration(
              labelText: "Test Name (Internal 1 / 2 / Model)",
              helperText: "Use same test name to edit marks",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _totalMarksCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Total Marks",
              border: OutlineInputBorder(),
            ),
          ),
          if (isLoadingExisting)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  // ===================================================
  // STUDENT LIST
  // ===================================================
  Widget _studentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('students')
          .where('classId', isEqualTo: widget.classId)
          .snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = snapshot.data!.docs;
        if (students.isEmpty) {
          return const Center(child: Text("No students found"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: students.length,
          itemBuilder: (_, i) {
            final stu = students[i];
            final id = stu.id;

            marksControllers.putIfAbsent(id, () => TextEditingController());

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(stu['name']),
                subtitle: Text("Admission: ${stu['admissionNo']}"),
                trailing: SizedBox(
                  width: 80,
                  child: TextField(
                    controller: marksControllers[id],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: "Marks"),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===================================================
  // CLEANUP
  // ===================================================
  @override
  void dispose() {
    _testNameCtrl.dispose();
    _totalMarksCtrl.dispose();
    for (final c in marksControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ===================================================
  // SNACK
  // ===================================================
  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

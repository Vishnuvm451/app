import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:darzo/teacher/teacher_dashboard.dart';

class EditSetupPage extends StatefulWidget {
  const EditSetupPage({super.key});

  @override
  State<EditSetupPage> createState() => _EditSetupPageState();
}

class _EditSetupPageState extends State<EditSetupPage> {
  // ---------------- STATE ----------------
  String? teacherDocId;

  String? departmentId;
  String? departmentName;

  final List<String> selectedClassIds = [];
  final List<String> selectedSubjectIds = [];

  int? currentSemesterFilter;

  bool isSaving = false;
  bool isApproved = false;
  bool setupCompleted = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Color primaryBlue = const Color(0xFF2196F3);
  final Color bgLight = const Color(0xFFF5F7FB);

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  // ---------------- LOAD TEACHER ----------------
  Future<void> _loadTeacherProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final query = await _db
          .collection('teacher')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _showSnack("Teacher profile not found");
        return;
      }

      final snap = query.docs.first;
      teacherDocId = snap.id;
      final data = snap.data();

      isApproved = data['isApproved'] == true;
      setupCompleted = data['setupCompleted'] == true;

      if (!isApproved) {
        _showSnack("Your account is not approved yet");
        return;
      }

      departmentId = data['departmentId'];

      if (departmentId != null) {
        final dept = await _db
            .collection('department')
            .doc(departmentId!)
            .get();
        departmentName = dept.data()?['name'];
      }

      if (setupCompleted) {
        selectedClassIds
          ..clear()
          ..addAll(List<String>.from(data['classIds'] ?? []));

        selectedSubjectIds
          ..clear()
          ..addAll(List<String>.from(data['subjectIds'] ?? []));

        currentSemesterFilter = data['semester'];
      }

      if (mounted) setState(() {});
    } catch (e) {
      _showSnack("Failed to load teacher profile");
    }
  }

  void _goBackToDashboard() {
    if (!mounted) return;
    Navigator.pop(context);
  }

  // ---------------- SAVE SETUP ----------------
  Future<void> _saveSetup() async {
    if (teacherDocId == null) {
      _showSnack("Teacher profile missing");
      return;
    }

    if (departmentId == null ||
        selectedClassIds.isEmpty ||
        selectedSubjectIds.isEmpty) {
      _showSnack("Select department, classes, and subjects");
      return;
    }

    setState(() => isSaving = true);

    try {
      await _db.collection('teacher').doc(teacherDocId).update({
        'departmentId': departmentId,
        'classIds': selectedClassIds,
        'subjectIds': selectedSubjectIds,
        'semester': currentSemesterFilter,
        'setupCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
      );
    } catch (e) {
      _showSnack("Failed to save setup");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goBackToDashboard();
        }
      },
      child: Scaffold(
        backgroundColor: bgLight,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.5,
          title: const Text(
            "Profile Setup",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryBlue),
            onPressed: _goBackToDashboard,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _wrap(_departmentDropdown()),
            const SizedBox(height: 16),
            _wrap(_classMultiSelect()),
            const SizedBox(height: 16),
            _wrap(_semesterDropdown()),
            const SizedBox(height: 16),
            _wrap(_subjectsMultiSelect()),
            const SizedBox(height: 30),
            _saveButton(),
            _summarySection(),
          ],
        ),
      ),
    );
  }

  Widget _wrap(Widget child) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ---------------- WIDGETS ----------------

  Widget _departmentDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('department').orderBy('name').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: departmentId,
          decoration: InputDecoration(
            labelText: "Department",
            prefixIcon: Icon(Icons.apartment, color: primaryBlue),
            border: InputBorder.none,
          ),
          items: snap.data!.docs
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d['name'])))
              .toList(),
          onChanged: (val) {
            setState(() {
              departmentId = val;
              selectedClassIds.clear();
              selectedSubjectIds.clear();
              currentSemesterFilter = null;
            });
          },
        );
      },
    );
  }

  Widget _classMultiSelect() {
    if (departmentId == null) return const Text("Select Department first");

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('class')
          .where('departmentId', isEqualTo: departmentId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        return ExpansionTile(
          title: const Text("Select Classes"),
          subtitle: Text("${selectedClassIds.length} Selected"),
          children: snap.data!.docs.map((d) {
            final id = d.id;
            return CheckboxListTile(
              title: Text(d['name']),
              value: selectedClassIds.contains(id),
              activeColor: primaryBlue,
              onChanged: (val) {
                setState(
                  () => val!
                      ? selectedClassIds.add(id)
                      : selectedClassIds.remove(id),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _semesterDropdown() {
    return DropdownButtonFormField<int>(
      value: currentSemesterFilter,
      decoration: InputDecoration(
        labelText: "Filter Subjects by Semester",
        prefixIcon: Icon(Icons.filter_list, color: primaryBlue),
        border: InputBorder.none,
      ),
      items: List.generate(
        8,
        (i) => DropdownMenuItem(value: i + 1, child: Text("Semester ${i + 1}")),
      ),
      onChanged: (val) => setState(() => currentSemesterFilter = val),
    );
  }

  Widget _subjectsMultiSelect() {
    if (selectedClassIds.isEmpty) {
      return const Text("Select at least one class");
    }
    if (currentSemesterFilter == null) {
      return const Text("Select semester to view subjects");
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('subject')
          .where('classId', whereIn: selectedClassIds)
          .where('semester', isEqualTo: currentSemesterFilter)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();

        if (snap.data!.docs.isEmpty) {
          return const Text("No subjects found");
        }

        return ExpansionTile(
          title: const Text("Select Subjects"),
          subtitle: Text("${selectedSubjectIds.length} Selected"),
          initiallyExpanded: true,
          children: snap.data!.docs.map((d) {
            final id = d.id;
            return CheckboxListTile(
              title: Text(d['name']),
              value: selectedSubjectIds.contains(id),
              activeColor: primaryBlue,
              onChanged: (val) {
                setState(
                  () => val!
                      ? selectedSubjectIds.add(id)
                      : selectedSubjectIds.remove(id),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _saveButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: isSaving ? null : _saveSetup,
        child: isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "SAVE CHANGES",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  // --- SUMMARY SECTION (ENHANCED, UI ONLY) ---
  Widget _summarySection() {
    if (selectedClassIds.isEmpty && selectedSubjectIds.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: primaryBlue),
              const SizedBox(width: 8),
              Text(
                "Your Selections",
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // ---------- CLASSES ----------
          if (selectedClassIds.isNotEmpty) ...[
            const Text(
              "Classes",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...selectedClassIds.map(
              (id) => FutureBuilder<DocumentSnapshot>(
                future: _db.collection('class').doc(id).get(),
                builder: (_, snap) {
                  if (!snap.hasData) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      "• ${snap.data!['name']}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ---------- SUBJECTS ----------
          if (selectedSubjectIds.isNotEmpty) ...[
            const Text(
              "Subjects",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ...selectedSubjectIds.map(
              (id) => FutureBuilder<DocumentSnapshot>(
                future: _db.collection('subject').doc(id).get(),
                builder: (_, snap) {
                  if (!snap.hasData) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      "• ${snap.data!['name']}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:darzo/teacher/teacher_dashboard.dart';
import 'package:darzo/auth/login.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  // --- STATE ---
  // Department is single select (root filter)
  String? departmentId;
  String? departmentName;

  // Classes are MULTI-select
  final List<String> selectedClassIds = [];

  // Semester is used to FILTER the subject list (single select for viewing)
  int? currentSemesterFilter;

  // Subjects are MULTI-select
  final List<String> selectedSubjectIds = [];

  bool isSaving = false;
  bool isApproved = false;
  bool setupCompleted = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Theme Colors
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color bgLight = const Color(0xFFF5F7FB);

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  // ---------------- LOAD PROFILE ----------------
  Future<void> _loadTeacherProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snap = await _db.collection('teacher').doc(user.uid).get();
    if (!snap.exists) return;

    final data = snap.data()!;
    isApproved = data['isApproved'] == true;
    setupCompleted = data['setupCompleted'] == true;

    if (!isApproved) {
      _showSnack("Your account is not approved yet");
      return;
    }

    departmentId = data['departmentId'];
    if (departmentId != null) {
      final d = await _db.collection('department').doc(departmentId!).get();
      if (mounted) setState(() => departmentName = d['name']);
    }

    if (setupCompleted) {
      setState(() {
        // Load Lists
        if (data['classIds'] != null) {
          selectedClassIds.clear();
          selectedClassIds.addAll(List<String>.from(data['classIds']));
        }
        if (data['subjectIds'] != null) {
          selectedSubjectIds.clear();
          selectedSubjectIds.addAll(List<String>.from(data['subjectIds']));
        }
        // Load last used semester or default
        currentSemesterFilter = data['semester'];
      });
    }

    if (mounted) setState(() {});
  }

  void _goToLogin() {
    FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // ---------------- SAVE ----------------
  Future<void> _saveSetup() async {
    if (departmentId == null ||
        selectedClassIds.isEmpty ||
        selectedSubjectIds.isEmpty) {
      _showSnack("Please select department, classes, and subjects");
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => isSaving = true);

    try {
      await _db.collection('teacher').doc(user.uid).update({
        'departmentId': departmentId,
        'classIds': selectedClassIds, // Saving List
        'semester': currentSemesterFilter, // Saving last filter (optional)
        'subjectIds': selectedSubjectIds, // Saving List
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToLogin();
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
            onPressed: _goToLogin,
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildWrapper(_departmentDropdown()),
            const SizedBox(height: 16),
            _buildWrapper(_classMultiSelect()),
            const SizedBox(height: 16),
            _buildWrapper(_semesterDropdown()),
            const SizedBox(height: 16),
            _buildWrapper(_subjectsMultiSelect()),
            const SizedBox(height: 30),
            _saveButton(),
            _buildSelectionList(), // ✅ LIST SELECTIONS UNDER SAVE BUTTON
          ],
        ),
      ),
    );
  }

  Widget _buildWrapper(Widget child) {
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

  // 1. Department Dropdown (Single Select)
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
              // Reset dependent lists when department changes
              selectedClassIds.clear();
              selectedSubjectIds.clear();
              currentSemesterFilter = null;
            });
          },
        );
      },
    );
  }

  // 2. Class Multi-Select (Expansion Tile)
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
          leading: Icon(Icons.school, color: primaryBlue),
          children: snap.data!.docs.map((d) {
            final id = d.id;
            return CheckboxListTile(
              title: Text(d['name']),
              activeColor: primaryBlue,
              value: selectedClassIds.contains(id),
              onChanged: (val) {
                setState(() {
                  val! ? selectedClassIds.add(id) : selectedClassIds.remove(id);
                  // If classes change, we might need to re-verify subjects,
                  // but keeping them selected is often better UX.
                });
              },
            );
          }).toList(),
        );
      },
    );
  }

  // 3. Semester Dropdown (Simple Filter)
  Widget _semesterDropdown() {
    // ✅ REMOVED UG/PG RESTRICTIONS - Showing all semesters
    return DropdownButtonFormField<int>(
      value: currentSemesterFilter,
      decoration: InputDecoration(
        labelText: "Filter Subjects by Semester",
        prefixIcon: Icon(Icons.filter_list, color: primaryBlue),
        border: InputBorder.none,
      ),
      items: [1, 2, 3, 4, 5, 6, 7, 8]
          .map((s) => DropdownMenuItem(value: s, child: Text("Semester $s")))
          .toList(),
      onChanged: (val) {
        setState(() {
          currentSemesterFilter = val;
        });
      },
    );
  }

  // 4. Subjects Multi-Select (Filtered by Classes AND Semester)
  Widget _subjectsMultiSelect() {
    if (selectedClassIds.isEmpty)
      return const Text("Select at least one Class");
    if (currentSemesterFilter == null)
      return const Text("Select Semester to view subjects");

    return StreamBuilder<QuerySnapshot>(
      // ✅ Valid Firestore Query: whereIn (Field A) + isEqualTo (Field B)
      stream: _db
          .collection('subject')
          .where('classId', whereIn: selectedClassIds)
          .where('semester', isEqualTo: currentSemesterFilter)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();

        if (snap.data!.docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("No subjects found for these classes/semester."),
          );
        }

        return ExpansionTile(
          title: const Text("Select Subjects"),
          subtitle: Text("${selectedSubjectIds.length} Selected"),
          leading: Icon(Icons.book, color: primaryBlue),
          initiallyExpanded: true, // Auto-open to show subjects
          children: snap.data!.docs.map((d) {
            final id = d.id;
            return CheckboxListTile(
              title: Text(d['name']),
              activeColor: primaryBlue,
              value: selectedSubjectIds.contains(id),
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
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: isSaving ? null : _saveSetup,
        child: isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "SAVE CHANGES",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
      ),
    );
  }

  // --- THE NEW SUMMARY SECTION ---
  Widget _buildSelectionList() {
    if (selectedClassIds.isEmpty && selectedSubjectIds.isEmpty)
      return const SizedBox();

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
          const Divider(),

          // List Selected Classes
          if (selectedClassIds.isNotEmpty) ...[
            const Text(
              "Classes:",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            ...selectedClassIds.map(
              (id) => FutureBuilder<DocumentSnapshot>(
                future: _db.collection('class').doc(id).get(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox(); // loading hidden
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      "• ${snap.data?['name'] ?? 'Unknown Class'}",
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          // List Selected Subjects
          if (selectedSubjectIds.isNotEmpty) ...[
            const Text(
              "Subjects:",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            ...selectedSubjectIds.map(
              (id) => FutureBuilder<DocumentSnapshot>(
                future: _db.collection('subject').doc(id).get(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      "• ${snap.data?['name'] ?? 'Unknown Subject'}",
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

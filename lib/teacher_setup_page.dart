import 'package:darzo/new/auth_provider.dart';
import 'package:darzo/new/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  String? selectedClassId;
  String? courseType;
  int? year;
  int? selectedSemester;

  final List<String> selectedSubjectIds = [];
  bool isLoading = false;

  // --------------------------------------------------
  // SEMESTER LOCK LOGIC
  // --------------------------------------------------
  List<int> _allowedSemesters() {
    if (courseType == null || year == null) return [];

    if (courseType == 'UG') {
      if (year == 1) return [1, 2];
      if (year == 2) return [3, 4];
      if (year == 3) return [5, 6];
    }

    if (courseType == 'PG') {
      if (year == 1) return [1, 2];
      if (year == 2) return [3, 4];
    }

    return [];
  }

  // --------------------------------------------------
  // SAVE SETUP
  // --------------------------------------------------
  Future<void> _completeSetup() async {
    if (selectedClassId == null ||
        selectedSemester == null ||
        selectedSubjectIds.isEmpty) {
      _showSnack("Complete all selections");
      return;
    }

    setState(() => isLoading = true);

    try {
      final auth = context.read<AuthProvider>();

      await FirestoreService.instance.completeTeacherSetup(
        uid: auth.user!.uid,
        classIds: [selectedClassId!],
        subjectIds: selectedSubjectIds,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
      );
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final deptId = auth.departmentId!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Setup"),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _title("Department"),
          Text(deptId, style: const TextStyle(fontWeight: FontWeight.bold)),

          const SizedBox(height: 20),

          // ---------------- CLASS ----------------
          _title("Select Class"),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: FirestoreService.instance.getClassesByDepartment(deptId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator();
              }

              final classes = snapshot.data!;

              return DropdownButtonFormField<String>(
                value: selectedClassId,
                items: classes.map<DropdownMenuItem<String>>((c) {
                  return DropdownMenuItem<String>(
                    value: c['id'],
                    child: Text(c['name']),
                  );
                }).toList(),
                onChanged: (val) {
                  final cls = classes.firstWhere((c) => c['id'] == val);

                  setState(() {
                    selectedClassId = val;
                    courseType = cls['courseType'];
                    year = cls['year'];
                    selectedSemester = null;
                    selectedSubjectIds.clear();
                  });
                },
              );
            },
          ),

          const SizedBox(height: 20),

          // ---------------- SEMESTER ----------------
          if (selectedClassId != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title("Select Semester"),
                DropdownButtonFormField<int>(
                  value: selectedSemester,
                  items: _allowedSemesters()
                      .map<DropdownMenuItem<int>>(
                        (s) => DropdownMenuItem<int>(
                          value: s,
                          child: Text("Semester $s"),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      selectedSemester = val;
                      selectedSubjectIds.clear();
                    });
                  },
                ),
              ],
            ),

          const SizedBox(height: 20),

          // ---------------- SUBJECTS ----------------
          if (selectedSemester != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title("Select Subjects"),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: FirestoreService.instance.getSubjects(
                    departmentId: deptId,
                    courseType: courseType!,
                    semester: selectedSemester!,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const CircularProgressIndicator();
                    }

                    final subjects = snapshot.data!;

                    return Column(
                      children: subjects.map((s) {
                        return CheckboxListTile(
                          value: selectedSubjectIds.contains(s['id']),
                          title: Text(s['name']),
                          onChanged: (val) {
                            setState(() {
                              val!
                                  ? selectedSubjectIds.add(s['id'])
                                  : selectedSubjectIds.remove(s['id']);
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),

          const SizedBox(height: 30),

          ElevatedButton(
            onPressed: isLoading ? null : _completeSetup,
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("COMPLETE SETUP"),
          ),
        ],
      ),
    );
  }

  Widget _title(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}

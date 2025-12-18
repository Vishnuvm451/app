import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherSetupPage extends StatefulWidget {
  const TeacherSetupPage({super.key});

  @override
  State<TeacherSetupPage> createState() => _TeacherSetupPageState();
}

class _TeacherSetupPageState extends State<TeacherSetupPage> {
  String? classId;
  int? semester;
  List<String> selectedSubjects = [];

  String? departmentId;

  @override
  void initState() {
    super.initState();
    _loadTeacherDept();
  }

  Future<void> _loadTeacherDept() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(uid)
        .get();
    setState(() => departmentId = doc['departmentId']);
  }

  Future<void> saveSetup() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    await FirebaseFirestore.instance.collection('teachers').doc(uid).update({
      'teachingClassId': classId,
      'teachingSemester': semester,
      'subjectIds': selectedSubjects,
      'setupCompleted': true,
    });

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (departmentId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Setup")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// CLASS
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('classes')
                .where('departmentId', isEqualTo: departmentId)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const CircularProgressIndicator();

              return DropdownButtonFormField<String>(
                value: classId,
                hint: const Text("Select Class"),
                items: snap.data!.docs
                    .map(
                      (d) =>
                          DropdownMenuItem(value: d.id, child: Text(d['name'])),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  classId = v;
                  semester = null;
                  selectedSubjects.clear();
                }),
              );
            },
          ),

          const SizedBox(height: 16),

          /// SEMESTER
          DropdownButtonFormField<int>(
            value: semester,
            hint: const Text("Semester"),
            items: [1, 2, 3, 4, 5, 6]
                .map((s) => DropdownMenuItem(value: s, child: Text("Sem $s")))
                .toList(),
            onChanged: (v) => setState(() {
              semester = v;
              selectedSubjects.clear();
            }),
          ),

          const SizedBox(height: 20),

          /// SUBJECTS
          if (classId != null && semester != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('subjects')
                  .where('classId', isEqualTo: classId)
                  .where('semester', isEqualTo: semester)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) return const CircularProgressIndicator();

                return Column(
                  children: snap.data!.docs.map((d) {
                    return CheckboxListTile(
                      title: Text(d['name']),
                      value: selectedSubjects.contains(d.id),
                      onChanged: (v) {
                        setState(() {
                          v!
                              ? selectedSubjects.add(d.id)
                              : selectedSubjects.remove(d.id);
                        });
                      },
                    );
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 24),

          ElevatedButton(onPressed: saveSetup, child: const Text("Save Setup")),
        ],
      ),
    );
  }
}

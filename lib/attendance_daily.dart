import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AttendanceDailyPage extends StatefulWidget {
  const AttendanceDailyPage({super.key});

  @override
  State<AttendanceDailyPage> createState() => _AttendanceDailyPageState();
}

class _AttendanceDailyPageState extends State<AttendanceDailyPage> {
  String? classId;
  int? semester;
  String? departmentId;

  String? subjectId;
  List<String> teacherSubjectIds = [];

  final Map<String, String> attendance = {}; // studentId → status

  @override
  void initState() {
    super.initState();
    _loadTeacherSetup();
  }

  Future<void> _loadTeacherSetup() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(uid)
        .get();

    setState(() {
      departmentId = doc['departmentId'];
      classId = doc['teachingClassId'];
      semester = doc['teachingSemester'];
      teacherSubjectIds = List<String>.from(doc['subjectIds']);
    });
  }

  Future<void> _saveAttendance() async {
    if (subjectId == null) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final today = DateTime.now().toIso8601String().split('T')[0];

    // 1️⃣ CREATE ATTENDANCE SESSION
    final sessionRef = await FirebaseFirestore.instance
        .collection('attendance_sessions')
        .add({
          'teacherId': uid,
          'departmentId': departmentId,
          'classId': classId,
          'subjectId': subjectId,
          'semester': semester,
          'date': today,
          'created_at': FieldValue.serverTimestamp(),
        });

    // 2️⃣ SAVE ATTENDANCE RECORDS
    final batch = FirebaseFirestore.instance.batch();

    attendance.forEach((studentId, status) {
      batch.set(
        FirebaseFirestore.instance.collection('attendance_records').doc(),
        {
          'sessionId': sessionRef.id,
          'studentId': studentId,
          'status': status,
          'markedBy': 'manual',
          'timestamp': FieldValue.serverTimestamp(),
        },
      );
    });

    await batch.commit();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Attendance saved")));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (classId == null || teacherSubjectIds.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Daily Attendance")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// SUBJECT SELECTION
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('subjects')
                .where(FieldPath.documentId, whereIn: teacherSubjectIds)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const CircularProgressIndicator();
              }

              return DropdownButtonFormField<String>(
                value: subjectId,
                hint: const Text("Select Subject"),
                items: snap.data!.docs
                    .map(
                      (d) =>
                          DropdownMenuItem(value: d.id, child: Text(d['name'])),
                    )
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    subjectId = v;
                    attendance.clear();
                  });
                },
              );
            },
          ),

          const SizedBox(height: 20),

          /// STUDENT LIST
          if (subjectId != null)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .where('classId', isEqualTo: classId)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const CircularProgressIndicator();
                }

                return Column(
                  children: snap.data!.docs.map((doc) {
                    final sid = doc.id;

                    return Card(
                      child: ListTile(
                        title: Text(doc['name']),
                        subtitle: Text(doc['register_number']),
                        trailing: DropdownButton<String>(
                          value: attendance[sid],
                          hint: const Text("Status"),
                          items: const [
                            DropdownMenuItem(
                              value: 'present',
                              child: Text("Present"),
                            ),
                            DropdownMenuItem(
                              value: 'half-day',
                              child: Text("Half Day"),
                            ),
                            DropdownMenuItem(
                              value: 'absent',
                              child: Text("Absent"),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() {
                              attendance[sid] = v!;
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

          const SizedBox(height: 30),

          /// SAVE BUTTON
          ElevatedButton(
            onPressed: subjectId == null ? null : _saveAttendance,
            child: const Text("Save Attendance"),
          ),
        ],
      ),
    );
  }
}

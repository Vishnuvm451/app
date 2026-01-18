import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentInternalMarksPage extends StatefulWidget {
  const StudentInternalMarksPage({super.key});

  @override
  State<StudentInternalMarksPage> createState() =>
      _StudentInternalMarksPageState();
}

class _StudentInternalMarksPageState extends State<StudentInternalMarksPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  String classId = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentClass();
  }

  // --------------------------------------------------
  // LOAD STUDENT CLASS
  // --------------------------------------------------
  Future<void> _loadStudentClass() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw "User not logged in";
    }

    final q = await FirebaseFirestore.instance
        .collection('student')
        .where('authUid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      throw "Student profile not found";
    }

    final studentDoc = q.docs.first;
    final data = studentDoc.data();

    // ✅ USE the variable (this removes the warning)
    classId = data['classId'];

    setState(() {});
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Internal Marks"), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _marksList(),
    );
  }

  // --------------------------------------------------
  // INTERNAL MARKS LIST
  // --------------------------------------------------
  Widget _marksList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('internal_mark')
          .where('classId', isEqualTo: classId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final tests = snapshot.data!.docs;

        if (tests.isEmpty) {
          return const Center(child: Text("No internal marks published yet"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tests.length,
          itemBuilder: (_, index) {
            final test = tests[index];

            return FutureBuilder<DocumentSnapshot>(
              future: test.reference.collection('student').doc(uid).get(),
              builder: (_, stuSnap) {
                if (!stuSnap.hasData || !stuSnap.data!.exists) {
                  return const SizedBox(); // not marked
                }

                final marks = stuSnap.data!['marks'];
                final total = test['totalMarks'];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      test['testName'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("Subject ID: ${test['subjectId']}"),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "$marks / $total",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

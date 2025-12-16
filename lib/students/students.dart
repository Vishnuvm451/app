import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentStudentsListPage extends StatefulWidget {
  const StudentStudentsListPage({super.key});

  @override
  State<StudentStudentsListPage> createState() =>
      _StudentStudentsListPageState();
}

class _StudentStudentsListPageState extends State<StudentStudentsListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? department;
  String? year;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMyClass();
  }

  // FETCH LOGGED-IN STUDENT CLASS
  Future<void> _loadMyClass() async {
    final uid = _auth.currentUser!.uid;

    final doc = await _firestore.collection("students").doc(uid).get();

    if (!doc.exists) return;

    setState(() {
      department = doc["department"];
      year = doc["year"];
      isLoading = false;
    });
  }

  // FETCH STUDENTS FROM SAME CLASS
  Stream<QuerySnapshot> _studentsStream() {
    return _firestore
        .collection("students")
        .where("department", isEqualTo: department)
        .where("year", isEqualTo: year)
        .orderBy("admission_no")
        .snapshots();
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Class Students"),
        backgroundColor: Colors.blue.shade800,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _studentsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No students found"));
                }

                final students = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final data = students[index].data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            data["admission_no"].toString().substring(
                              data["admission_no"].length - 2,
                            ),
                          ),
                        ),
                        title: Text(data["name"]),
                        subtitle: Text("Admission No: ${data["admission_no"]}"),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

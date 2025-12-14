import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentStudentsListPage extends StatelessWidget {
  const StudentStudentsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("My Class Students")),
      body: FutureBuilder<DocumentSnapshot>(
        // 1️⃣ Get logged-in student's profile
        future: FirebaseFirestore.instance
            .collection("students")
            .doc(uid)
            .get(),
        builder: (context, studentSnap) {
          if (!studentSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!studentSnap.data!.exists) {
            return const Center(child: Text("Student profile not found"));
          }

          final studentData = studentSnap.data!.data() as Map<String, dynamic>;

          final department = studentData['department'];
          final year = studentData['year'];

          // 2️⃣ Query students of SAME class
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("students")
                .where("department", isEqualTo: department)
                .where("year", isEqualTo: year)
                .snapshots(),
            builder: (context, listSnap) {
              if (!listSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = listSnap.data!.docs;

              if (docs.isEmpty) {
                return const Center(child: Text("No students found"));
              }

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(data['name']),
                      subtitle: Text("${data['department']} • ${data['year']}"),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

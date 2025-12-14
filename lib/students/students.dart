import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentStudentsListPage extends StatelessWidget {
  const StudentStudentsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Class Students"),
        backgroundColor: const Color(0xFF2196F3),
      ),

      // --------------------------------------------------
      // STEP 1: Get logged-in student's admission number
      // --------------------------------------------------
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection("students")
            .doc(uid)
            .get(),
        builder: (context, studentSnap) {
          if (studentSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!studentSnap.hasData || !studentSnap.data!.exists) {
            return const Center(child: Text("Student profile not found"));
          }

          final String admissionNo =
              (studentSnap.data!.data()
                  as Map<String, dynamic>)['admission_no'];

          // --------------------------------------------------
          // STEP 2: Get class from ADMIN data
          // --------------------------------------------------
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection("student_master")
                .doc(admissionNo)
                .get(),
            builder: (context, masterSnap) {
              if (masterSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!masterSnap.hasData || !masterSnap.data!.exists) {
                return const Center(
                  child: Text("Admin student record not found"),
                );
              }

              final masterData =
                  masterSnap.data!.data() as Map<String, dynamic>;

              final String department = masterData['department'];
              final String year = masterData['year'];

              // --------------------------------------------------
              // STEP 3: Fetch classmates from ADMIN records
              // --------------------------------------------------
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("student_master")
                    .where("department", isEqualTo: department)
                    .where("year", isEqualTo: year)
                    .orderBy("roll_no")
                    .snapshots(),
                builder: (context, classSnap) {
                  if (classSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!classSnap.hasData || classSnap.data!.docs.isEmpty) {
                    return const Center(child: Text("No students found"));
                  }

                  final classmates = classSnap.data!.docs
                      .where((doc) => doc.id != admissionNo)
                      .toList();

                  if (classmates.isEmpty) {
                    return const Center(
                      child: Text("You are the only student in this class"),
                    );
                  }

                  // --------------------------------------------------
                  // STEP 4: Display list
                  // --------------------------------------------------
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: classmates.length,
                    itemBuilder: (context, index) {
                      final data =
                          classmates[index].data() as Map<String, dynamic>;

                      return _StudentTile(data: data);
                    },
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

// ======================================================
// STUDENT LIST TILE
// ======================================================
class _StudentTile extends StatelessWidget {
  final Map<String, dynamic> data;

  const _StudentTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final String admissionNo = data['admission_no'];
    final int rollNo = data['roll_no'];
    final String name = data['name'];

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection("attendance_summary")
          .doc(admissionNo)
          .get(),
      builder: (context, snap) {
        double attendancePercent = 0;
        bool hasData = false;

        if (snap.hasData && snap.data!.exists) {
          final att = snap.data!.data() as Map<String, dynamic>;
          final int present = att['present_periods'] ?? 0;
          final int total = att['total_periods'] ?? 0;

          if (total > 0) {
            attendancePercent = (present / total) * 100;
            hasData = true;
          }
        }

        final Color attColor = attendancePercent >= 75
            ? Colors.green
            : Colors.red;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Roll No : $rollNo",
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text("Admission No : $admissionNo"),
                const SizedBox(height: 6),
                Text(
                  hasData
                      ? "Attendance : ${attendancePercent.toStringAsFixed(1)} %"
                      : "Attendance : --",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hasData ? attColor : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

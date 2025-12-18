import 'package:darzo/new/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'attendance_summary.dart';
import 'mark_attendance_page.dart';
import 'view_internals.dart';
import 'student_classmates.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  bool isLoading = true;

  String studentName = '';
  String departmentId = '';
  String classId = '';

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  // --------------------------------------------------
  // LOAD STUDENT DATA
  // --------------------------------------------------
  Future<void> _loadStudent() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final student = await FirestoreService.instance.getStudent(uid);
    if (student == null) return;

    setState(() {
      studentName = student['name'];
      departmentId = student['departmentId'];
      classId = student['classId'];
      isLoading = false;
    });
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Dashboard"),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(),
          const SizedBox(height: 20),
          _attendanceCard(),
          const SizedBox(height: 20),
          _quickActions(),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // HEADER
  // --------------------------------------------------
  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hello, $studentName 👋",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Department: $departmentId",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // ATTENDANCE SUMMARY (PLACEHOLDER FOR NOW)
  // --------------------------------------------------
  Widget _attendanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: const [
          Text(
            "Attendance Summary",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            "Available after attendance module",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // QUICK ACTIONS
  // --------------------------------------------------
  Widget _quickActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _actionCard(
          icon: Icons.check_circle_outline,
          label: "Mark Attendance",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MarkAttendancePage(
                  classId: classId,
                  departmentId: departmentId,
                ),
              ),
            );
          },
        ),
        _actionCard(
          icon: Icons.pie_chart,
          label: "Attendance",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StudentAttendanceSummaryPage(),
              ),
            );
          },
        ),
        _actionCard(
          icon: Icons.assignment,
          label: "Internals",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StudentInternalMarksPage(),
              ),
            );
          },
        ),
        _actionCard(
          icon: Icons.people,
          label: "Classmates",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentViewClassmatesPage(classId: classId),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.blue),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

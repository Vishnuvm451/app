import 'package:darzo/mark_attendance_face.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:darzo/login.dart';
import 'package:darzo/new/firestore_service.dart';

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

  /// attendanceStatus values:
  /// loading | no-session | not-marked | present | half-day | absent
  String attendanceStatus = 'loading';

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  // --------------------------------------------------
  // LOAD STUDENT PROFILE + TODAY ATTENDANCE STATUS
  // --------------------------------------------------
  Future<void> _loadStudentData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final student = await FirestoreService.instance.getStudent(uid);

    if (student == null) return;

    studentName = student['name'];
    departmentId = student['departmentId'];
    classId = student['classId'];

    final status = await FirestoreService.instance.getTodayAttendanceStatus(
      studentId: uid,
      classId: classId,
    );

    setState(() {
      attendanceStatus = status ?? 'no-session';
      isLoading = false;
    });
  }

  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: const Text("Student Dashboard"),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 24),
                    _attendanceCard(),
                    const SizedBox(height: 20),
                    _quickActions(),
                  ],
                ),
              ),
            ),
    );
  }

  // --------------------------------------------------
  // HEADER
  // --------------------------------------------------
  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.school, size: 64, color: Colors.white),
        const SizedBox(height: 12),
        Text(
          "Welcome, $studentName 👋",
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Class ID: $classId",
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // ATTENDANCE CARD (STATUS + BUTTON)
  // --------------------------------------------------
  Widget _attendanceCard() {
    Color color;
    String text;
    bool canMark = false;

    switch (attendanceStatus) {
      case 'present':
        color = Colors.green;
        text = "Present Today ✅";
        break;
      case 'half-day':
        color = Colors.orange;
        text = "Half Day ⏳";
        break;
      case 'absent':
        color = Colors.red;
        text = "Absent ❌";
        break;
      case 'not-marked':
        color = Colors.blue;
        text = "Attendance Not Marked";
        canMark = true;
        break;
      case 'no-session':
        color = Colors.grey;
        text = "No Attendance Session Today";
        break;
      default:
        color = Colors.grey;
        text = "Checking Attendance...";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.face),
              label: const Text(
                "Mark Attendance",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: canMark
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MarkAttendancePage(),
                        ),
                      );
                      // refresh status after return
                      setState(() {
                        isLoading = true;
                      });
                      _loadStudentData();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canMark
                    ? const Color(0xFF2196F3)
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // QUICK ACTIONS
  // --------------------------------------------------
  Widget _quickActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _actionCard(
                icon: Icons.bar_chart,
                title: "Attendance Summary",
                onTap: () {},
              ),
              _actionCard(
                icon: Icons.assignment,
                title: "Internal Marks",
                onTap: () {},
              ),
              _actionCard(
                icon: Icons.people,
                title: "Classmates",
                onTap: () {},
              ),
              _actionCard(
                icon: Icons.settings,
                title: "Settings",
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:darzo/attendance_daily.dart';
import 'package:darzo/internal.dart';
import 'package:darzo/new/firestore_service.dart';
import 'package:darzo/start_attendance.dart';
import 'package:darzo/teacher_student.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'teacher_setup_page.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  bool isLoading = true;

  String teacherName = '';
  String departmentId = '';
  bool setupCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadTeacher();
  }

  // --------------------------------------------------
  // LOAD TEACHER PROFILE
  // --------------------------------------------------
  Future<void> _loadTeacher() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final teacher = await FirestoreService.instance.getTeacher(uid);
    if (teacher == null) return;

    // Force setup one-time
    if (teacher['setupCompleted'] == false) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherSetupPage()),
      );
      return;
    }

    setState(() {
      teacherName = teacher['name'] ?? '';
      departmentId = teacher['departmentId'] ?? '';
      setupCompleted = teacher['setupCompleted'] ?? false;
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
        title: const Text("Teacher Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [_header(), const SizedBox(height: 20), _quickActions()],
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
        color: Colors.indigo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Welcome, $teacherName 👋",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Department: $departmentId",
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // QUICK ACTIONS (UPDATED)
  // --------------------------------------------------
  Widget _quickActions() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        // 🔥 START ATTENDANCE (NEW)
        _actionCard(
          icon: Icons.play_circle_fill,
          label: "Start Attendance",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StartAttendancePage()),
            );
          },
        ),

        _actionCard(
          icon: Icons.check_circle_outline,
          label: "Attendance",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AttendanceDailyPage()),
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
                builder: (_) => const AddInternalMarksBulkPage(),
              ),
            );
          },
        ),

        _actionCard(
          icon: Icons.people,
          label: "Students",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TeacherStudentsListPage(),
              ),
            );
          },
        ),

        _actionCard(
          icon: Icons.settings,
          label: "Teaching Setup",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherSetupPage()),
            );
          },
        ),
      ],
    );
  }

  // --------------------------------------------------
  // ACTION CARD
  // --------------------------------------------------
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
          border: Border.all(color: Colors.indigo.shade200),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: Colors.indigo),
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

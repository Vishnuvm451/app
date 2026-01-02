import 'package:darzo/attendance/attendance_daily.dart';
import 'package:darzo/teacher/internal.dart';
import 'package:darzo/attendance/start_attendance.dart';
import 'package:darzo/teacher/teacher_student.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/auth/login.dart';
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
  String classId = '';
  bool setupCompleted = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

    final snap = await _db.collection('teacher').doc(uid).get();

    if (!mounted) return;

    if (!snap.exists) {
      await _logout();
      return;
    }

    final data = snap.data()!;

    // 🔒 approval check
    if (data['isApproved'] != true) {
      _showSnack("Your account is not approved");
      await _logout();
      return;
    }

    // 🔒 force setup
    if (data['setupCompleted'] != true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const TeacherSetupPage()),
      );
      return;
    }

    setState(() {
      teacherName = data['name'] ?? '';
      departmentId = data['departmentId'] ?? '';
      classId = data['classId'] ?? '';
      setupCompleted = true;
      isLoading = false;
    });
  }

  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
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
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
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
          icon: Icons.play_circle_fill,
          label: "Start Attendance",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TeacherAttendanceSessionPage(),
              ),
            );
          },
        ),

        _actionCard(
          icon: Icons.check_circle_outline,
          label: "Attendance",
          onTap: classId.isEmpty
              ? _showSetupError
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManualAttendancePage(classId: classId),
                    ),
                  );
                },
        ),

        _actionCard(
          icon: Icons.assignment,
          label: "Internals",
          onTap: classId.isEmpty
              ? _showSetupError
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddInternalMarksPage(
                        classId: classId,
                        subjectId: 'default',
                      ),
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
          onTap: setupCompleted
              ? _showSetupCompleted
              : () {
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

  // --------------------------------------------------
  // HELPERS
  // --------------------------------------------------
  void _showSetupError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Complete teaching setup first")),
    );
  }

  void _showSetupCompleted() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Setup already completed")));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

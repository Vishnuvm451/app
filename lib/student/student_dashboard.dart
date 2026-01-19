import 'package:darzo/attendance/attendance_summary.dart';
import 'package:darzo/student/mark_attendance_face.dart';
import 'package:darzo/student/student_internal_marks_page.dart';
import 'package:darzo/student/view_classmates_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:darzo/auth/login.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:darzo/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  bool isLoading = true;
  bool isSessionActive = false;

  String classId = '';

  /// loading | no-session | not-marked | present | half-day | absent
  String attendanceStatus = 'loading';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // --------------------------------------------------
  // LOAD DASHBOARD DATA
  // --------------------------------------------------
  Future<void> _loadDashboardData() async {
    try {
      final auth = context.read<AppAuthProvider>();
      final user = auth.user;

      if (user == null) {
        await _logout();
        return;
      }

      final student = await FirestoreService.instance.getStudent(user.uid);

      if (student == null) {
        _setNoSession();
        return;
      }

      classId = student['classId'] ?? '';
      if (classId.isEmpty) {
        _setNoSession();
        return;
      }

      // ✅ CHECK ACTIVE ATTENDANCE SESSION
      final sessionQuery = await FirebaseFirestore.instance
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      isSessionActive = sessionQuery.docs.isNotEmpty;

      // ✅ LOAD FINAL ATTENDANCE (if any)
      final finalStatus = await FirestoreService.instance
          .getTodayFinalAttendance(studentId: user.uid, classId: classId);

      if (!mounted) return;

      setState(() {
        attendanceStatus =
            finalStatus ?? (isSessionActive ? 'not-marked' : 'no-session');
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        attendanceStatus = 'no-session';
        isLoading = false;
      });
    }
  }

  void _setNoSession() {
    setState(() {
      attendanceStatus = 'no-session';
      isLoading = false;
    });
  }

  // --------------------------------------------------
  // LOGOUT
  // --------------------------------------------------
  Future<void> _logout() async {
    await context.read<AppAuthProvider>().logout();
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
    final auth = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: const Text("Student Dashboard", style: TextStyle(fontSize: 26)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 34),
            onPressed: _logout,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _header(auth),
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
  Widget _header(AppAuthProvider auth) {
    return Column(
      children: [
        const Icon(Icons.school, size: 70, color: Colors.white),
        const SizedBox(height: 12),
        Text(
          "Welcome, ${auth.name ?? 'Student'} 👋",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        if (classId.isNotEmpty)
          Text(
            "Class ID: $classId",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
      ],
    );
  }

  // --------------------------------------------------
  // ATTENDANCE CARD
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
        canMark = isSessionActive;
        break;
      case 'no-session':
        color = Colors.grey;
        text = "Waiting for Teacher to Start Attendance";
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
              label: Text(
                canMark ? "Mark Attendance" : "Waiting for Teacher",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: canMark
                  ? () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MarkAttendancePage(),
                        ),
                      );

                      if (!mounted) return;

                      setState(() {
                        isLoading = true;
                        attendanceStatus = 'loading';
                      });

                      _loadDashboardData();
                    }
                  : null,
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
                Icons.bar_chart,
                "Attendance Summary",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MonthlyAttendanceSummaryPage(),
                    ),
                  );
                },
              ),
              _actionCard(
                Icons.assignment,
                "Internal Marks",
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
                Icons.people,
                "Classmates",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ViewClassmatesPage(),
                    ),
                  );
                },
              ),
              _actionCard(Icons.settings, "Settings", onTap: _comingSoon),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String title, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
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

  void _comingSoon() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Coming soon 🚧")));
  }
}

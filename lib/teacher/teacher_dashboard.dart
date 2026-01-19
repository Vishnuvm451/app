import 'package:darzo/attendance/attendance_daily.dart';
import 'package:darzo/settings.dart';
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

  // Theme Colors
  final Color primaryBlue = const Color(0xFF1E88E5); // Richer Blue
  final Color bgWhite = const Color(0xFFF5F7FA); // Clean Off-White

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

    try {
      final snap = await _db.collection('teacher').doc(uid).get();

      if (!mounted) return;

      if (!snap.exists) {
        await _logout();
        return;
      }

      final data = snap.data()!;

      if (data['isApproved'] != true) {
        _showSnack("Your account is not approved");
        await _logout();
        return;
      }

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
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
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
  // UI BUILD
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: bgWhite,
        body: Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    }

    return Scaffold(
      backgroundColor: primaryBlue, // Top background is Blue
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -------------------------
            // 1. TOP HEADER SECTION
            // -------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              child: Column(
                children: [
                  // App Bar Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Dashboard",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Teacher Panel",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                          ),
                          onPressed: _logout,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  // Profile Card
                  _buildProfileRow(),
                ],
              ),
            ),

            // -------------------------
            // 2. WHITE BODY SECTION
            // -------------------------
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: bgWhite,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const Text(
                      "Quick Actions",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _quickActionsGrid(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // PROFILE ROW WIDGET
  // --------------------------------------------------
  Widget _buildProfileRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: Colors.blue, size: 30),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, $teacherName",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  departmentId.isEmpty ? "No Dept" : departmentId.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // GRID ACTIONS
  // --------------------------------------------------
  Widget _quickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0, // Square cards look cleaner
      children: [
        _actionCard(
          icon: Icons.qr_code_scanner_rounded,
          label: "Start\nAttendance",
          color: const Color(0xFF2196F3),
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
          icon: Icons.checklist_rtl_rounded,
          label: "Mark\nAttendance",
          color: const Color(0xFFFF9800),
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
          icon: Icons.edit_note_rounded,
          label: "Internal\nMarks",
          color: const Color(0xFF9C27B0),
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
          icon: Icons.group_rounded,
          label: "My\nStudents",
          color: const Color(0xFF4CAF50),
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
          icon: Icons.settings_suggest_rounded,
          label: "Edit\nSetup",
          color: const Color(0xFF009688),

          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TeacherSetupPage()),
            );
          },
        ),

        // Inside _quickActionsGrid in TeacherDashboardPage.dart
        _actionCard(
          icon: Icons.settings,
          label: "Settings",
          color: Colors.blueGrey,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsPage(
                  userRole: 'teacher',
                  initialName: teacherName,
                  initialSubTitle: "Dept: ${departmentId.toUpperCase()}",
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // --------------------------------------------------
  // INDIVIDUAL ACTION CARD
  // --------------------------------------------------
  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
            ],
          ),
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

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

    try {
      final snap = await _db.collection('teacher').doc(uid).get();

      if (!mounted) return;

      if (!snap.exists) {
        await _logout();
        return;
      }

      final data = snap.data()!;

      // 🔒 Approval Check
      if (data['isApproved'] != true) {
        _showSnack("Your account is not approved");
        await _logout();
        return;
      }

      // 🔒 Force Setup
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
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.blue, // Light modern background
      appBar: AppBar(
        title: const Text(
          "Dashboard",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        children: [
          _header(),
          const SizedBox(height: 24),
          const Text(
            "Quick Actions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _quickActions(),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // HEADER
  // --------------------------------------------------
  Widget _header() {
    // ✅ FIX: Define Color locally to prevent "Undefined" errors
    const Color primaryBlue = Color(0xFF2196F3);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, const Color(0xFFFFFFFF).withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue.withOpacity(1),
            child: const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello  $teacherName",
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    departmentId.isEmpty ? "No Dept" : departmentId,
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
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
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _actionCard(
          icon: Icons.qr_code_scanner_rounded,
          label: "Start Attendance",
          color: Colors.blue,
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
          label: "Attendance Marking",
          color: Colors.orange,
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
          label: "Internal Marks",
          color: Colors.purple,
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
          label: "My Students",
          color: Colors.green,
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
          label: "Setup Class",
          color: Colors.teal,
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
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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

  void _showSetupCompleted() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Setup already completed")));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

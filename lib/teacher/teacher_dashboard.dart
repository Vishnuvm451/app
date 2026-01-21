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

  // 🆕 MULTI-SELECT SUPPORT
  List<String> classIds = [];
  List<String> subjectIds = [];

  bool setupCompleted = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Theme Colors
  final Color primaryBlue = const Color(0xFF1E88E5);
  final Color bgWhite = const Color(0xFFF5F7FA);

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

        // 🆕 Load Lists safely
        classIds = List<String>.from(data['classIds'] ?? []);
        subjectIds = List<String>.from(data['subjectIds'] ?? []);

        setupCompleted = true;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

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
      backgroundColor: primaryBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              child: Column(
                children: [
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
                  _buildProfileRow(),
                ],
              ),
            ),

            // 2. BODY
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
              Row(
                children: [
                  _infoBadge(
                    departmentId.isEmpty
                        ? "No Dept"
                        : departmentId.toUpperCase(),
                  ),
                  const SizedBox(width: 8),
                  // Show Count instead of ID
                  _infoBadge("${classIds.length} Classes"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _quickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        _actionCard(
          icon: Icons.qr_code_scanner_rounded,
          label: "Start\nAttendance",
          color: const Color(0xFF2196F3),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TeacherAttendanceSessionPage(),
            ),
          ),
        ),

        // 🆕 NEW LOGIC: Pick Class before Marking
        _actionCard(
          icon: Icons.checklist_rtl_rounded,
          label: "Mark\nAttendance",
          color: const Color(0xFFFF9800),
          onTap: () => _pickClassAndNavigate(
            (selectedId) => ManualAttendancePage(classId: selectedId),
          ),
        ),

        // 🆕 NEW LOGIC: Pick Class before Internal Marks
        _actionCard(
          icon: Icons.edit_note_rounded,
          label: "Internal\nMarks",
          color: const Color(0xFF9C27B0),
          onTap: () => _pickClassAndNavigate(
            (selectedId) =>
                AddInternalMarksPage(classId: selectedId, subjectId: 'default'),
          ),
        ),

        _actionCard(
          icon: Icons.group_rounded,
          label: "My\nStudents",
          color: const Color(0xFF4CAF50),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeacherStudentsListPage()),
          ),
        ),
        _actionCard(
          icon: Icons.settings_suggest_rounded,
          label: "Edit\nSetup",
          color: const Color(0xFF009688),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeacherSetupPage()),
          ),
        ),
        _actionCard(
          icon: Icons.settings,
          label: "Settings",
          color: Colors.blueGrey,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsPage(
                userRole: 'teacher',
                initialName: teacherName,
                initialSubTitle: "Dept: ${departmentId.toUpperCase()}",
              ),
            ),
          ),
        ),
      ],
    );
  }

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
  // 🆕 MULTI-CLASS SELECTION HELPER
  // --------------------------------------------------
  void _pickClassAndNavigate(Widget Function(String) pageBuilder) {
    if (classIds.isEmpty) {
      _showSnack("No classes assigned. Edit Setup.");
      return;
    }

    // If only 1 class, go directly
    if (classIds.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => pageBuilder(classIds.first)),
      );
      return;
    }

    // If multiple classes, show Bottom Sheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Select Class",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ...classIds.map(
                (id) => FutureBuilder<DocumentSnapshot>(
                  future: _db.collection('class').doc(id).get(),
                  builder: (context, snap) {
                    final name = snap.data?['name'] ?? "Loading...";
                    return ListTile(
                      leading: const Icon(
                        Icons.class_outlined,
                        color: Colors.blue,
                      ),
                      title: Text(name),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.pop(context); // Close sheet
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => pageBuilder(id)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

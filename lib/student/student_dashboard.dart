import 'package:darzo/attendance/attendance_summary.dart';
import 'package:darzo/settings.dart';
import 'package:darzo/student/mark_attendance_face.dart';
import 'package:darzo/student/student_internal_marks_page.dart';
import 'package:darzo/student/view_classmates_page.dart';
import 'package:darzo/student/student_timetable_page.dart';
import 'package:darzo/student/view_teachers_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:darzo/auth/login.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  bool isLoading = true;

  // Data Variables
  String studentName = "Loading...";
  String admissionNo = "";
  String classId = "";
  String departmentId = "";
  String currentSemester = ""; // ✅ Variable for Semester
  String studentDocId = "";
  String debugMsg = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initDashboardData();
  }

  // ==================================================
  // 1. DATA LOADER
  // ==================================================
  Future<void> _initDashboardData() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logout();
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();

        if (mounted) {
          setState(() {
            studentName = data['name'] ?? "Student";
            admissionNo = data['admissionNo'] ?? doc.id;
            classId = data['classId'] ?? "";
            departmentId = data['departmentId'] ?? "";
            // ✅ Fetch Semester (Default to 'Semester 1' if missing)
            currentSemester = data['semester'] ?? "Semester 6";

            studentDocId = doc.id;
            isLoading = false;
            debugMsg = "Success";
          });
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
            debugMsg = "No Profile Found for UID:\n${user.uid}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          debugMsg = "Error: $e";
        });
      }
    }
  }

  Future<void> _logout() async {
    await context.read<AppAuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  // ✅ NAVIGATION LOGIC
  void _navigateToTimetable() {
    if (classId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Class not assigned yet.")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentTimetablePage(
          classId: classId,
          currentSemester: currentSemester,
        ),
      ),
    );
  }

  // ==================================================
  // 2. MAIN UI
  // ==================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: const Text("Student Dashboard", style: TextStyle(fontSize: 26)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 9.0),
            child: IconButton(
              icon: const Icon(Icons.logout, size: 32),
              onPressed: _logout,
            ),
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

  // ==================================================
  // 3. HEADER
  // ==================================================
  Widget _header() {
    return Column(
      children: [
        const Icon(Icons.school, size: 70, color: Colors.white),
        const SizedBox(height: 12),
        Text(
          "Welcome, $studentName 👋",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        if (departmentId.isNotEmpty)
          Text(
            "Department: ${departmentId.replaceAll('_', ' ')}",
            style: const TextStyle(
              color: Color.fromARGB(197, 255, 255, 255),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  // ==================================================
  // 4. ATTENDANCE CARD
  // ==================================================
  Widget _attendanceCard() {
    if (classId.isEmpty || studentDocId.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 10),
            const Text(
              "Profile Error",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              debugMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _initDashboardData,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, sessionSnap) {
        if (!sessionSnap.hasData || sessionSnap.data!.docs.isEmpty) {
          return _buildCardUI(
            text: "No Active Session",
            color: Colors.grey,
            canMark: false,
          );
        }

        final sessionData =
            sessionSnap.data!.docs.first.data() as Map<String, dynamic>;
        final sessionType = sessionData['sessionType'];
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final attendanceDocId = "${classId}_${today}_$sessionType";

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .doc(attendanceDocId)
              .collection('student')
              .doc(studentDocId)
              .snapshots(),
          builder: (context, attendanceSnap) {
            bool isMarked =
                attendanceSnap.hasData && attendanceSnap.data!.exists;

            if (isMarked) {
              return _buildCardUI(
                text: "Present Today ✅",
                color: Colors.green,
                canMark: false,
                isMarked: true,
              );
            } else {
              return _buildCardUI(
                text: "Attendance Not Marked",
                color: Colors.blue,
                canMark: true,
              );
            }
          },
        );
      },
    );
  }

  Widget _buildCardUI({
    required String text,
    required Color color,
    required bool canMark,
    bool isMarked = false,
  }) {
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
            textAlign: TextAlign.center,
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
              icon: Icon(isMarked ? Icons.check_circle : Icons.face),
              label: Text(
                isMarked
                    ? "Marked Successfully"
                    : (canMark ? "Mark Attendance" : "Waiting for Teacher"),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canMark
                    ? const Color(0xFF2196F3)
                    : Colors.grey.shade300,
                foregroundColor: canMark ? Colors.white : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: canMark
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MarkAttendancePage(),
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // 5. QUICK ACTIONS
  // ==================================================
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
                      builder: (_) => const ViewClassmatesPage(),
                    ),
                  );
                },
              ),
              // 1. My Timetable Button (Navigates to the Timetable Page)
              _actionCard(
                Icons.calendar_month_rounded,
                "My Timetable",
                onTap: _navigateToTimetable,
              ),
              _actionCard(
                Icons.school_rounded,
                "My Teachers",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ViewTeachersPage()),
                  );
                },
              ),
              _actionCard(
                Icons.settings,
                "Settings",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsPage(
                        userRole: 'student',
                        initialName: studentName,
                        initialSubTitle: "Adm No: $admissionNo",
                      ),
                    ),
                  );
                },
              ),
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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

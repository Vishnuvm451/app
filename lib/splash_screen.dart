import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/admin/admin_dashboard.dart';
import 'package:darzo/parents/child_admisision_no.dart';
import 'package:darzo/parents/child_face_scan.dart';
import 'package:darzo/parents/parent_dashboard.dart';
import 'package:darzo/student/face_liveness_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:darzo/login.dart';
import 'package:darzo/student/student_dashboard.dart';
import 'package:darzo/teacher/teacher_dashboard.dart';
import 'package:darzo/teacher/teacher_setup_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Splash delay
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final authProvider = context.read<AppAuthProvider>();

    // Initialize auth provider (checks if user is already logged in)
    await authProvider.init();

    if (!mounted) return;

    // If no user is logged in, go to login page
    if (!authProvider.isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    // User is logged in - route based on role
    await _routeBasedOnRole(authProvider);
  }

  Future<void> _routeBasedOnRole(AppAuthProvider authProvider) async {
    try {
      final role = authProvider.role;
      final uid = authProvider.user!.uid;

      debugPrint("🚀 Splash Routing: Role=$role, UID=$uid");

      // ======================================================
      // ADMIN FLOW
      // ======================================================
      if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
        return;
      }

      // ======================================================
      // STUDENT FLOW
      // ======================================================
      if (role == 'student') {
        final studentQuery = await FirebaseFirestore.instance
            .collection('student')
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();

        if (studentQuery.docs.isEmpty) {
          await authProvider.logout();
          _navigateToLogin("Student record missing");
          return;
        }

        final studentDoc = studentQuery.docs.first;
        final admissionNo = studentDoc.id;
        final bool faceEnabled = studentDoc['face_enabled'] == true;

        if (!faceEnabled) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => FaceLivenessPage(
                admissionNo: admissionNo,
                studentName: studentDoc['name'],
              ),
            ),
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
        );
        return;
      }

      // ======================================================
      // TEACHER FLOW
      // ======================================================
      if (role == 'teacher') {
        if (!authProvider.isTeacherApproved) {
          await authProvider.logout();
          _navigateToLogin("Your account is pending admin approval");
          return;
        }

        if (!authProvider.isTeacherSetupCompleted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeacherSetupPage()),
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
        );
        return;
      }

      // ======================================================
      // PARENT FLOW (✅ ADDED)
      // ======================================================
      if (role == 'parent') {
        final parentDoc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(uid)
            .get();

        if (!parentDoc.exists) {
          await authProvider.logout();
          _navigateToLogin("Parent record missing");
          return;
        }

        final data = parentDoc.data()!;
        final bool childFaceLinked = data['child_face_linked'] == true;
        final String? linkedStudentId =
            (data['linked_student_id'] != null &&
                data['linked_student_id'].toString().isNotEmpty)
            ? data['linked_student_id'].toString().trim()
            : null;

        debugPrint(
          "👨‍👩‍👧 Parent: ID=$linkedStudentId, FaceLinked=$childFaceLinked",
        );

        // 1. If child NOT linked -> Connect Page
        if (linkedStudentId == null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ConnectChildPage()),
          );
          return;
        }

        // 2. If child linked but Face NOT verified -> Face Scan Page
        if (!childFaceLinked) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ParentFaceScanPage(
                admissionNo: linkedStudentId,
                studentName: "Child",
              ),
            ),
          );
          return;
        }

        // 3. All good -> Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParentDashboard()),
        );
        return;
      }

      // Invalid role - logout and go to login
      await authProvider.logout();
      _navigateToLogin("Invalid account type");
    } catch (e) {
      debugPrint("❌ Splash screen error: $e");
      await authProvider.logout();
      _navigateToLogin("Authentication error occurred");
    }
  }

  void _navigateToLogin(String message) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );

    // Show message after navigation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    });
  }

  // ===================================================
  // SPLASH UI
  // ===================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2BD6D6), Color.fromARGB(255, 60, 108, 240)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ Icon with animation
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: const Icon(Icons.school, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 20),
              Text(
                'DARZO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),

              // ✅ Loading indicator
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

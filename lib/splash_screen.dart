import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:darzo/auth/login.dart';
import 'package:darzo/student/student_dashboard.dart';
import 'package:darzo/teacher/teacher_dashboard.dart';
import 'package:darzo/teacher/teacher_setup_page.dart';
import 'package:darzo/student/face_capture.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

      // ======================================================
      // ADMIN FLOW
      // ======================================================
      if (role == 'admin') {
        // Navigate to admin dashboard (you need to implement this)
        // For now, going to login page - replace with admin dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
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
              builder: (_) => FaceCapturePage(
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

      // Invalid role - logout and go to login
      await authProvider.logout();
      _navigateToLogin("Invalid account type");
      
    } catch (e) {
      print("Splash screen error: $e");
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
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  // ===================================================
  // SPLASH UI (YOUR ORIGINAL DESIGN)
  // ===================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2BD6D6), Color(0xFF7B3CF0)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.school, size: 80, color: Colors.white),
              SizedBox(height: 20),
              Text(
                'DARZO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
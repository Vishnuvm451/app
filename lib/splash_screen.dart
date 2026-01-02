import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_provider.dart';
import 'auth/login.dart';
import 'admin/admin_dashboard.dart';
import 'student/student_dashboard.dart';
import 'teacher/teacher_dashboard.dart';
import 'teacher/teacher_setup_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Small splash delay (UI only)
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = context.read<AppAuthProvider>();

    // 🔴 THIS WAS MISSING / WRONG BEFORE
    await auth.init();

    if (!mounted) return;

    _navigate(auth);
  }

  void _navigate(AppAuthProvider auth) {
    // NOT LOGGED IN → LOGIN PAGE
    if (!auth.isLoggedIn) {
      _go(const LoginPage());
      return;
    }

    // ADMIN
    if (auth.isAdmin) {
      _go(const AdminDashboardPage());
      return;
    }

    // STUDENT
    if (auth.isStudent) {
      _go(const StudentDashboardPage());
      return;
    }

    // TEACHER
    if (auth.isTeacher) {
      _go(
        auth.isTeacherSetupCompleted
            ? const TeacherDashboardPage()
            : const TeacherSetupPage(),
      );
      return;
    }

    // FALLBACK
    _go(const LoginPage());
  }

  void _go(Widget page) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  // ===================================================
  // SPLASH UI (UNCHANGED)
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

import 'dart:async';
import 'package:darzo/admin_dashboard.dart';
import 'package:darzo/login.dart';
import 'package:darzo/student_dashboard.dart';
import 'package:darzo/teacher_dashboard.dart';
import 'package:darzo/teacher_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'new/firebase_options.dart';

import 'package:darzo/new/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppAuthProvider())],
      child: const MyApp(),
    ),
  );
}

// =======================================================
// ROOT APP
// =======================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darzo',
      debugShowCheckedModeBanner: false,

      // 🔵 KEEP YOUR EXISTING THEME
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF2196F3),
        scaffoldBackgroundColor: const Color(0xFF2196F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),

      home: const SplashScreen(),
    );
  }
}

// =======================================================
// SPLASH SCREEN (LOGIC ONLY)
// =======================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authProvider = context.read<AppAuthProvider>();
    await authProvider.init();

    _route(authProvider);
  }

  void _route(AppAuthProvider auth) {
    if (!auth.isLoggedIn) {
      _go(const LoginPage());
      return;
    }

    if (auth.isAdmin) {
      _go(const AdminDashboardPage());
      return;
    }

    if (auth.isStudent) {
      _go(const StudentDashboardPage());
      return;
    }

    if (auth.isTeacher) {
      _go(
        auth.isTeacherSetupCompleted
            ? const TeacherDashboardPage()
            : const TeacherSetupPage(),
      );
      return;
    }

    _go(const LoginPage());
  }

  void _go(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
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
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Image.asset(
                  'assets/darzo_logo.png',
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.school, size: 80, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
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

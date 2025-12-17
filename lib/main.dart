import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/dashboard/admin_panel.dart';
import 'package:darzo/dashboard/student_dashboard.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// Imports for your pages (Ensure these exist or will be created in next steps)
import 'package:darzo/login.dart';
import 'package:darzo/dashboard/teacher_dashboard.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Darzo',
      // ✅ GLOBAL BLUE THEME (Kept exactly as you requested)
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF2196F3),
        scaffoldBackgroundColor: const Color(0xFF2196F3),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2196F3)),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _handleStartUp();
  }

  // 🔥 NEW: Check for existing login session
  Future<void> _handleStartUp() async {
    // Wait for the splash animation/timer (2 seconds)
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // 1. No User -> Go to Login
      _navigateTo(const LoginPage());
    } else {
      // 2. User Exists -> Check Role in Firestore
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          String role = userDoc.get('role');

          // Route based on role
          if (role == 'admin') {
            _navigateTo(const AdminDashboardPage());
          } else if (role == 'teacher') {
            _navigateTo(const TeacherDashboardPage());
          } else if (role == 'student') {
            _navigateTo(const StudentDashboardPage());
          } else {
            // Fallback for unknown role
            _navigateTo(const LoginPage());
          }
        } else {
          // User in Auth but not in Firestore? Rare, but safe to logout.
          await FirebaseAuth.instance.signOut();
          _navigateTo(const LoginPage());
        }
      } catch (e) {
        // Error fetching role (e.g. network), go to login
        _navigateTo(const LoginPage());
      }
    }
  }

  void _navigateTo(Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

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
              // Logo
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  // Placeholder shadow for better visibility
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/darzo_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if image missing
                      return const Icon(
                        Icons.school,
                        size: 80,
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "DARZO",
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

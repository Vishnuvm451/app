// 1. IMPORT YOUR EXISTING ADMIN LOGIN PAGE
import 'package:darzo/admin_login.dart'; // Ensure this matches the file name of your Admin Login Page
import 'package:darzo/student_dashboard.dart';
import 'package:darzo/new/student_register.dart';
import 'package:darzo/teacher_dashboard.dart';
import 'package:darzo/teacher_register.dart';
import 'package:darzo/teacher_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isStudent = true;
  bool showPassword = false;
  bool isLoading = false;

  final Color primaryBlue = const Color(0xFF2196F3);

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // LOGIN LOGIC (Student & Teacher Only)
  // ======================================================
  Future<void> _login() async {
    if (emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      _showSnack("Enter email & password");
      return;
    }

    setState(() => isLoading = true);

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      if (isStudent) {
        // STUDENT CHECK
        final snap = await _db.collection('students').doc(uid).get();
        if (!snap.exists || snap.data()?['role'] != 'student') {
          throw "Not a student account";
        }
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
          );
        }
      } else {
        // TEACHER CHECK
        final snap = await _db.collection('teachers').doc(uid).get();
        if (!snap.exists) throw "Teacher profile not found";

        final data = snap.data()!;
        bool isSetupDone = data['setupCompleted'] ?? false;

        if (mounted) {
          if (isSetupDone) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TeacherSetupPage()),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Login failed";
      if (e.code == 'user-not-found')
        msg = "User not found";
      else if (e.code == 'wrong-password')
        msg = "Wrong password";
      _showSnack(msg);
    } catch (e) {
      _showSnack("Error: ${e.toString()}");
      await _auth.signOut();
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ======================================================
  // UI BUILD
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              // 🔥 UPDATED: ADMIN ICON -> Navigate to Your Admin Page
              Positioned(
                top: 8,
                right: 12,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: IconButton(
                    icon: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 50,
                    ),
                    tooltip: "Admin Login",
                    onPressed: () {
                      // Navigate to your existing AdminLoginPage
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminLoginPage(),
                        ),
                      );
                    },
                  ),
                ),
              ),

              Column(
                children: [
                  const SizedBox(height: 30),
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      Icons.access_time,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "DARZO",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // LOGIN FORM
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      children: [
                        // Toggle Buttons
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              _toggleButton("STUDENT LOGIN", true),
                              _toggleButton("TEACHER LOGIN", false),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        _inputField(
                          hint: isStudent ? "Student Email" : "Teacher Email",
                          icon: Icons.school,
                          controller: emailCtrl,
                        ),
                        _passwordField(),
                        const SizedBox(height: 20),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "LOGIN",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        Text(
                          "Forgot Password?",
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),

                        // Register Buttons
                        _registerButton(
                          "REGISTER AS STUDENT",
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentRegisterPage(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _registerButton(
                          "REGISTER AS TEACHER",
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TeacherRegisterPage(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- HELPERS ----------------
  Widget _toggleButton(String text, bool student) {
    return Expanded(
      child: GestureDetector(
        onTap: isLoading ? null : () => setState(() => isStudent = student),
        child: Container(
          height: 45,
          decoration: BoxDecoration(
            color: isStudent == student ? primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isStudent == student ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        enabled: !isLoading,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: passwordCtrl,
        enabled: !isLoading,
        obscureText: !showPassword,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        decoration: InputDecoration(
          hintText: "Password",
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
            onPressed: isLoading
                ? null
                : () => setState(() => showPassword = !showPassword),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _registerButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

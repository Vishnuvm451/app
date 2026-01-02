import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/admin/admin_login.dart';
import 'package:darzo/student/face_capture.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:darzo/student/student_register.dart';
import 'package:darzo/student/student_dashboard.dart';
import 'package:darzo/teacher/teacher_dashboard.dart';
import 'package:darzo/teacher/teacher_register.dart';
import 'package:darzo/teacher/teacher_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:darzo/auth/forgot_password_page.dart';

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

  // ======================================================
  // LOGIN
  // ======================================================
  Future<void> _login() async {
    if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) {
      _showSnack("Enter email and password");
      return;
    }

    setState(() => isLoading = true);

    try {
      // ---------- AUTH ----------
      await context.read<AppAuthProvider>().login(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack("Login failed");
        return;
      }

      // ---------- EMAIL VERIFICATION ----------
      await user.reload();
      if (!user.emailVerified) {
        _showSnack("Please verify your email before logging in");
        await FirebaseAuth.instance.signOut();
        return;
      }

      final uid = user.uid;

      // ---------- ROLE ----------
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        _showSnack("User record not found");
        return;
      }

      final String role = userDoc['role'];

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
          _showSnack("Student record missing");
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
        final teacherDoc = await FirebaseFirestore.instance
            .collection('teacher')
            .doc(uid)
            .get();

        if (!teacherDoc.exists) {
          _showSnack("Teacher profile not found");
          return;
        }

        final bool isApproved = teacherDoc['isApproved'] == true;
        final bool setupCompleted = teacherDoc['setupCompleted'] == true;

        if (!isApproved) {
          _showSnack("Your account is not approved yet");
          await FirebaseAuth.instance.signOut();
          return;
        }

        if (!setupCompleted) {
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

      _showSnack("Invalid role detected");
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // UI (UNCHANGED)
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 12,
                child: IconButton(
                  icon: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 50,
                  ),
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminLoginPage(),
                            ),
                          );
                        },
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
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      children: [
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
                          icon: Icons.email,
                          controller: emailCtrl,
                        ),
                        _passwordField(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text("Forgot Password?"),
                          ),
                        ),
                        const SizedBox(height: 20),
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
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "LOGIN",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
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

  // ======================================================
  // HELPERS
  // ======================================================
  Widget _toggleButton(String text, bool student) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isStudent = student),
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
        obscureText: !showPassword,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        decoration: InputDecoration(
          hintText: "Password",
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => showPassword = !showPassword),
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
        onPressed: onTap,
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

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

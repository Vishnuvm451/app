import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/admin/admin_login.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:darzo/student/face_liveness_page.dart';
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
    // 1. Basic Validation
    if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) {
      _showCleanSnackBar(
        "Please enter both email and password.",
        isError: true,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 2. AUTHENTICATION
      await context.read<AppAuthProvider>().login(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Login failed. Please try again.";

      final uid = user.uid;

      // ======================================================
      // 3. CHECK USER PROFILE (Common 'users' collection)
      // ======================================================
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      // 🚨 TEACHER NOT APPROVED YET / ACCOUNT PENDING
      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        throw "Your account is pending approval from Admin.";
      }

      final String role = userDoc['role'];

      // ======================================================
      // 4. STUDENT FLOW
      // ======================================================
      if (role == 'student') {
        final studentQuery = await FirebaseFirestore.instance
            .collection('student')
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();

        if (studentQuery.docs.isEmpty) {
          throw "Student profile data is missing.";
        }

        final studentDoc = studentQuery.docs.first;
        final admissionNo = studentDoc.id;
        final bool faceEnabled = studentDoc['face_enabled'] == true;

        if (!mounted) return;

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
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
          );
        }
        return;
      }

      // ======================================================
      // 5. TEACHER FLOW
      // ======================================================
      if (role == 'teacher') {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('teacher')
            .doc(uid)
            .get();

        if (!teacherDoc.exists) {
          throw "Teacher profile data is missing.";
        }

        // Check if Teacher is Approved AND Setup is Done
        final bool isApproved = teacherDoc['isApproved'] == true;
        final bool setupCompleted = teacherDoc['setupCompleted'] == true;

        if (!isApproved) {
          await FirebaseAuth.instance.signOut();
          throw "Your Teacher account is not approved yet.";
        }

        if (!mounted) return;

        if (!setupCompleted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeacherSetupPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
          );
        }
        return;
      }

      throw "Unknown user role detected.";
    } on FirebaseAuthException catch (e) {
      // 🔥 SPECIFIC FIREBASE ERROR HANDLING
      String message;
      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          message = "Incorrect email or password.";
          break;
        case 'invalid-email':
          message = "The email format is invalid.";
          break;
        case 'user-disabled':
          message = "This account has been disabled.";
          break;
        case 'network-request-failed':
          message = "No internet connection.";
          break;
        case 'too-many-requests':
          message = "Too many attempts. Try again later.";
          break;
        default:
          message = "Login Error: ${e.message}";
      }
      _showCleanSnackBar(message, isError: true);
    } catch (e) {
      // 🔥 GENERIC ERROR HANDLING
      // Removes "Exception:" prefix to make it look cleaner
      String cleanError = e.toString().replaceAll("Exception:", "").trim();
      _showCleanSnackBar(cleanError, isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ==========================================
  // ✨ PASTE THIS HELPER AT THE BOTTOM OF PAGE
  // ==========================================
  void _showCleanSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
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
                top: 5,
                right: 25,
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
}

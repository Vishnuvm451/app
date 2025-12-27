import 'package:darzo/admin_login.dart';
import 'package:darzo/new/auth_provider.dart';
import 'package:darzo/new/student_register.dart';
import 'package:darzo/teacher_register.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  // LOGIN (AUTH PROVIDER)
  // ======================================================
  Future<void> _login() async {
    if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) {
      _showSnack("Enter email and password");
      return;
    }

    setState(() => isLoading = true);

    try {
      await context.read<AppAuthProvider>().login(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );
      // ❌ No navigation here
      // ✅ SplashScreen decides routing
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ======================================================
  // FORGOT PASSWORD
  // ======================================================
  Future<void> _forgotPassword() async {
    final email = emailCtrl.text.trim();

    if (email.isEmpty) {
      _showSnack("Enter your email to reset password");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _showSnack("Password reset email sent");
    } on FirebaseAuthException catch (e) {
      String msg = "Failed to send reset email";

      if (e.code == 'user-not-found') {
        msg = "No user found with this email";
      } else if (e.code == 'invalid-email') {
        msg = "Invalid email address";
      }

      _showSnack(msg);
    } catch (_) {
      _showSnack("Something went wrong. Try again.");
    }
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              // ADMIN LOGIN ICON
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
                        // LOGIN TOGGLE
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
                        const SizedBox(height: 12),

                        // FORGOT PASSWORD
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: isLoading ? null : _forgotPassword,
                            child: Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                                      fontSize: 16,
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

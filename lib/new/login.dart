import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_login.dart';

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
  // LOGIN FUNCTION (ROLE BASED)
  // ======================================================
  Future<void> _login() async {
    if (emailCtrl.text.trim().isEmpty ||
        passwordCtrl.text.trim().isEmpty) {
      _showSnack("Enter email & password");
      return;
    }

    try {
      setState(() => isLoading = true);

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        _showSnack("User role not found");
        return;
      }

      final role = userDoc['role'];

      if (isStudent && role != 'student') {
        _showSnack("Not a student account");
        return;
      }

      if (!isStudent && role != 'teacher') {
        _showSnack("Not a teacher account");
        return;
      }

      // 🔁 NAVIGATION (replace with your dashboards)
      if (role == 'student') {
        _showSnack("Student Login Success", success: true);
        // Navigator.pushReplacement(...StudentDashboard());
      } else if (role == 'teacher') {
        _showSnack("Teacher Login Success", success: true);
        // Navigator.pushReplacement(...TeacherDashboard());
      }

    } catch (e) {
      _showSnack(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: Stack(
          children: [
            // 🔐 ADMIN ICON
            Positioned(
              top: 10,
              right: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminLoginPage(),
                    ),
                  );
                },
              ),
            ),

            // MAIN CONTENT
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.access_time,
                        size: 40, color: Colors.white),
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
                        // TOGGLE
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              _toggle("STUDENT LOGIN", true),
                              _toggle("TEACHER LOGIN", false),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        _input(
                          "Email",
                          Icons.email,
                          emailCtrl,
                        ),

                        _password(),

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
                                    color: Colors.white)
                                : const Text(
                                    "LOGIN",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),
                        const Text("Forgot Password?"),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),

                        _button("REGISTER AS STUDENT"),
                        const SizedBox(height: 10),
                        _button("REGISTER AS TEACHER"),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // WIDGETS
  // ======================================================
  Widget _toggle(String text, bool student) {
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

  Widget _input(String hint, IconData icon, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
        ],
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _password() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: passwordCtrl,
        obscureText: !showPassword,
        inputFormatters: [
          FilteringTextInputFormatter.deny(RegExp(r'\s')),
        ],
        decoration: InputDecoration(
          hintText: "Password",
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(showPassword
                ? Icons.visibility
                : Icons.visibility_off),
            onPressed: () =>
                setState(() => showPassword = !showPassword),
          ),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _button(String text) {
    return SizedBox(
      width: double.infinity,
      height: 45,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}
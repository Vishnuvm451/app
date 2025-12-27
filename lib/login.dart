import 'package:darzo/admin_class_sub.dart';
import 'package:darzo/new/student_register.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// TODO: replace with your real pages
import 'student_dashboard.dart';
import 'teacher_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isStudent = true;
  bool showPassword = false;

  final Color primaryBlue = const Color(0xFF2196F3);

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ======================================================
  // LOGIN LOGIC
  // ======================================================
  Future<void> login() async {
    if (emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      _showSnack("Enter email & password");
      return;
    }

    try {
      // 1️⃣ Firebase Auth
      final cred = await _auth.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2️⃣ Decide collection based on toggle
      final collection = isStudent ? 'students' : 'teachers';

      final snap = await _db.collection(collection).doc(uid).get();

      if (!snap.exists) {
        _showSnack("Account not found in $collection");
        return;
      }

      final role = snap['role'];

      // 3️⃣ Role-based navigation
      if (role == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
        );
      } else if (role == 'teacher') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
        );
      } else {
        _showSnack("Invalid role");
      }
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  // ======================================================
  // ADMIN ICON LOGIN
  // ======================================================
  Future<void> adminLogin() async {
    if (emailCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      _showSnack("Enter admin credentials");
      return;
    }

    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      final snap = await _db.collection('admins').doc(uid).get();

      if (!snap.exists || snap['role'] != 'admin') {
        _showSnack("Not an admin account");
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminClassSubjectPage()),
      );
    } catch (e) {
      _showSnack(e.toString());
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
        child: SingleChildScrollView(
          child: Stack(
            children: [
              // ================= ADMIN ICON =================
              Positioned(
                top: 8,
                right: 12,
                child: IconButton(
                  icon: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: adminLogin,
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

                  // ================= WHITE CARD =================
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

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              "LOGIN",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),

                        _registerButton("REGISTER AS STUDENT", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentRegisterPage(),
                            ),
                          );
                        }),
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
  // UI HELPERS
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
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

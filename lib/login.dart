import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/admin_dashboard.dart';
import 'package:darzo/admin_login.dart';
import 'package:darzo/student_dashboard.dart';
import 'package:darzo/student_register.dart';
import 'package:darzo/teacher_dashboard.dart';
import 'package:darzo/teacher_register.dart';
import 'package:darzo/teacher_setup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ===============================
/// ROOT PAGE
/// ===============================
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SmartAttendanceScreen();
  }
}

/// ===============================
/// MAIN LOGIN SCREEN
/// ===============================
class SmartAttendanceScreen extends StatelessWidget {
  const SmartAttendanceScreen({super.key});

  static const Color primaryBlue = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, size: 34),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: const [_Header(), SizedBox(height: 24), LoginCard()],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// HEADER
/// ===============================
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Text(
          'DARZO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        SizedBox(height: 16),
        Icon(Icons.access_time, size: 56, color: Colors.white),
      ],
    );
  }
}

/// ===============================
/// LOGIN CARD
/// ===============================
class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  bool isStudentSelected = true;
  bool isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _showSnack(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  /// ===============================
  /// LOGIN LOGIC
  /// ===============================
  Future<void> _login() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showSnack("Enter email and password");
      return;
    }

    setState(() => isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = cred.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _showSnack("User profile not found");
        return;
      }

      final role = userDoc['role'];

      if (!mounted) return;

      if (role == 'student') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
        );
      } else if (role == 'teacher') {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('teachers')
            .doc(uid)
            .get();

        if (!teacherDoc.exists || teacherDoc['isApproved'] != true) {
          await FirebaseAuth.instance.signOut();
          _showSnack("Teacher not approved");
          return;
        }

        if (teacherDoc['setupCompleted'] == true) {
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
      } else if (role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Login failed");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _LoginToggle(
            isStudent: isStudentSelected,
            onStudent: () => setState(() => isStudentSelected = true),
            onTeacher: () => setState(() => isStudentSelected = false),
          ),
          const SizedBox(height: 20),
          LoginForm(
            emailController: _emailController,
            passwordController: _passwordController,
            isLoading: isLoading,
            onLogin: _login,
          ),
          const Divider(),
          _registerButton("REGISTER AS STUDENT", const StudentRegisterPage()),
          const SizedBox(height: 12),
          _registerButton("REGISTER AS TEACHER", const TeacherRegisterPage()),
        ],
      ),
    );
  }

  Widget _registerButton(String text, Widget page) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        child: Text(text),
      ),
    );
  }
}

/// ===============================
/// LOGIN FORM (PASSWORD 👁 FIXED)
/// ===============================
class LoginForm extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLogin;

  const LoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
  });

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  bool _isPasswordVisible = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.emailController,
          keyboardType: TextInputType.emailAddress,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),

        /// 🔐 PASSWORD FIELD WITH 👁
        TextField(
          controller: widget.passwordController,
          obscureText: !_isPasswordVisible,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onLogin,
            child: widget.isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("LOGIN"),
          ),
        ),
      ],
    );
  }
}

/// ===============================
/// LOGIN TOGGLE
/// ===============================
class _LoginToggle extends StatelessWidget {
  final bool isStudent;
  final VoidCallback onStudent;
  final VoidCallback onTeacher;

  const _LoginToggle({
    required this.isStudent,
    required this.onStudent,
    required this.onTeacher,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _toggle("STUDENT", isStudent, onStudent),
        _toggle("TEACHER", !isStudent, onTeacher),
      ],
    );
  }

  Widget _toggle(String text, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

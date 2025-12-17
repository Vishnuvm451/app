import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/dashboard/admin_panel.dart';
import 'package:darzo/dashboard/student_dashboard.dart';
import 'package:darzo/dashboard/teacher_dashboard.dart';
import 'package:darzo/students/student_reg.dart';
import 'package:darzo/teacher/teacher_reg.dart';
import 'package:darzo/teacher/teacher_setup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin/admin_login.dart';

/// ===============================
///  ROOT APP
/// ===============================
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SmartAttendanceScreen();
  }
}

/// ===============================
///  MAIN SCREEN (SCAFFOLD)
/// ===============================
class SmartAttendanceScreen extends StatelessWidget {
  const SmartAttendanceScreen({super.key});

  static const Color primaryBlue = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 40),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminLoginPage()),
                );
              },
            ),
          ),
        ],
      ),
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                HeaderSection(),
                SizedBox(height: 24),
                LoginCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================
///  HEADER
/// ===============================
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text(
          'DARZO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.18),
          ),
          child: const Icon(Icons.access_time, size: 56, color: Colors.white),
        ),
      ],
    );
  }
}

/// ===============================
///  LOGIN CARD (UI SAME)
/// ===============================
class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  bool isStudentSelected = true;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// ===============================
  ///  FIXED LOGIN LOGIC (ONLY LOGIC CHANGED)
  /// ===============================
  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showSnack("Please enter email and password");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔐 AUTH FIRST (CRITICAL FIX)
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = cred.user!.uid;

      // 🔎 READ ROLE AFTER AUTH
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _showSnack("User profile not found");
        return;
      }

      final role = userDoc["role"];

      if (role == "student") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
        );
      } else if (role == "teacher") {
        // 4️⃣ CHECK SETUP STATUS
        final bool setupCompleted =
            userDoc.data()!.containsKey('profile_completed') &&
            userDoc['profile_completed'] == true;

        // 5️⃣ NAVIGATION
        if (setupCompleted) {
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
      } else if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
        );
      } else {
        _showSnack("Invalid user role");
      }
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Login failed");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          LoginToggle(
            isStudentSelected: isStudentSelected,
            onStudentTap: () => setState(() => isStudentSelected = true),
            onTeacherTap: () => setState(() => isStudentSelected = false),
          ),
          const SizedBox(height: 24),

          LoginForm(
            isStudentSelected: isStudentSelected,
            isLoading: _isLoading,
            idController: _emailController,
            passwordController: _passwordController,
            onLoginPressed: _handleLogin, // ✅ FIXED
            onForgotPassword: () {},
          ),
        ],
      ),
    );
  }
}

/// ===============================
///  LOGIN FORM (UI UNCHANGED)
/// ===============================
class LoginForm extends StatelessWidget {
  final bool isStudentSelected;
  final bool isLoading;
  final TextEditingController idController;
  final TextEditingController passwordController;
  final VoidCallback onLoginPressed;
  final VoidCallback onForgotPassword;

  const LoginForm({
    super.key,
    required this.isStudentSelected,
    required this.isLoading,
    required this.idController,
    required this.passwordController,
    required this.onLoginPressed,
    required this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = SmartAttendanceScreen.primaryBlue;

    return Column(
      children: [
        TextField(
          controller: idController,
          decoration: InputDecoration(
            labelText: isStudentSelected ? 'Student Email' : 'Teacher Email',
            prefixIcon: Icon(
              isStudentSelected ? Icons.school : Icons.person_outline,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue),
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: primaryBlue),
            ),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : onLoginPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'LOGIN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),

        TextButton(
          onPressed: onForgotPassword,
          child: const Text("Forgot Password?"),
        ),
        const Divider(),

        _buildRegisterButton(
          context,
          'REGISTER AS STUDENT',
          const StudentRegisterPage(),
        ),
        const SizedBox(height: 12),
        _buildRegisterButton(
          context,
          'REGISTER AS TEACHER',
          const TeacherRegisterPage(),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(BuildContext context, String text, Widget page) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: SmartAttendanceScreen.primaryBlue,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

/// ===============================
///  LOGIN TOGGLE (UNCHANGED)
/// ===============================
class LoginToggle extends StatelessWidget {
  final bool isStudentSelected;
  final VoidCallback onStudentTap;
  final VoidCallback onTeacherTap;

  const LoginToggle({
    super.key,
    required this.isStudentSelected,
    required this.onStudentTap,
    required this.onTeacherTap,
  });

  @override
  Widget build(BuildContext context) {
    const Color _ = SmartAttendanceScreen.primaryBlue;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildToggle("STUDENT LOGIN", isStudentSelected, onStudentTap),
          _buildToggle("TEACHER LOGIN", !isStudentSelected, onTeacherTap),
        ],
      ),
    );
  }

  Widget _buildToggle(String text, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? SmartAttendanceScreen.primaryBlue
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

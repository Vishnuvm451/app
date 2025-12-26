import 'package:darzo/admin_login.dart';

import 'package:darzo/new/auth_provider.dart';
import 'package:darzo/new/student_register.dart';
import 'package:darzo/teacher_register.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SmartAttendanceScreen();
  }
}

// =======================================================
// MAIN SCREEN
// =======================================================
class SmartAttendanceScreen extends StatelessWidget {
  const SmartAttendanceScreen({super.key});

  static const Color primaryBlue = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
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
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
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

// =======================================================
// HEADER
// =======================================================
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'DARZO',
          style: TextStyle(
            color: Colors.white,
            fontSize: 52,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
          ),
          child: const Icon(Icons.access_time, size: 56, color: Colors.white),
        ),
      ],
    );
  }
}

// =======================================================
// LOGIN CARD
// =======================================================
class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  bool isStudentSelected = true;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ===================================================
  // LOGIN HANDLER (PROVIDER BASED)
  // ===================================================
  Future<void> _login(BuildContext context) async {
    final auth = context.read<AuthProvider>();

    if (emailController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty) {
      _showSnack(context, "Please enter email & password");
      return;
    }

    try {
      await auth.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!auth.isLoggedIn) {
        _showSnack(context, "Login failed");
      }
      // ✅ SUCCESS → routing handled by main.dart
    } catch (e) {
      _showSnack(context, e.toString());
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          LoginToggle(
            isStudentSelected: isStudentSelected,
            onStudentTap: () => setState(() => isStudentSelected = true),
            onTeacherTap: () => setState(() => isStudentSelected = false),
          ),
          const SizedBox(height: 20),

          // EMAIL
          TextField(
            controller: emailController,
            decoration: InputDecoration(
              labelText: isStudentSelected ? "Student Email" : "Teacher Email",
              prefixIcon: Icon(isStudentSelected ? Icons.school : Icons.person),
            ),
          ),
          const SizedBox(height: 14),

          // PASSWORD
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: "Password",
              prefixIcon: Icon(Icons.lock),
            ),
          ),
          const SizedBox(height: 24),

          // LOGIN BUTTON
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: auth.isLoading ? null : () => _login(context),
              child: auth.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "LOGIN",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),

          const SizedBox(height: 10),

          TextButton(
            onPressed: () {
              _showSnack(context, "Password reset via admin / email");
            },
            child: const Text("Forgot Password?"),
          ),

          const Divider(),

          _registerButton(
            context,
            "REGISTER AS STUDENT",
            const StudentRegisterPage(),
          ),
          const SizedBox(height: 10),
          _registerButton(
            context,
            "REGISTER AS TEACHER",
            const TeacherRegisterPage(),
          ),
        ],
      ),
    );
  }

  Widget _registerButton(BuildContext context, String text, Widget page) {
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

// =======================================================
// LOGIN TOGGLE
// =======================================================
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _toggle("STUDENT", isStudentSelected, onStudentTap),
          _toggle("TEACHER", !isStudentSelected, onTeacherTap),
        ],
      ),
    );
  }

  Widget _toggle(String text, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? SmartAttendanceScreen.primaryBlue : null,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

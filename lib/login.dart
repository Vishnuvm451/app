import 'package:darzo/dashboard/student_dashboard.dart'; // Ensure this exists
import 'package:darzo/students/student_reg.dart';
import 'package:darzo/teacher/teacher_reg.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import 'package:flutter/material.dart';
import 'admin/admin_login.dart';

/// ===============================
///  ROOT APP
/// ===============================
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SmartAttendanceScreen();
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

//

/// ===============================
///  HEADER: TIME + TITLE + LOGO
/// ===============================
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        const Text(
          'DARZO',
          textAlign: TextAlign.center,
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
///  LOGIN CARD (LOGIC + UI)
/// ===============================
class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  bool isStudentSelected = true;
  bool _isLoading = false; // To show loading spinner

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- FIREBASE LOGIN FUNCTION ---
  Future<void> _handleLogin() async {
    // 1. Basic Validation
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Email and Password')),
      );
      return;
    }

    // 2. Start Loading
    setState(() {
      _isLoading = true;
    });

    try {
      // 3. Attempt Firebase Sign In
      // NOTE: Firebase Auth works with Emails. If your Teacher ID is not an email,
      // you must append a domain (e.g., id + "@school.com") before sending it here.
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 4. Navigate on Success
      if (mounted) {
        // Here you would typically check Firestore to verify if the user is actually
        // a Student or Teacher. For now, we route based on the toggle.
        if (isStudentSelected) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
          );
        } else {
          // Replace with TeacherDashboard when you have the file
          // Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TeacherDashboard()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged in as Teacher (Dashboard not linked)'),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // 5. Handle Firebase Errors
      String message = 'An error occurred';
      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password provided.';
      } else {
        message = e.message ?? message;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      // 6. Stop Loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        mainAxisSize: MainAxisSize.min,
        children: [
          LoginToggle(
            isStudentSelected: isStudentSelected,
            onStudentTap: () => setState(() => isStudentSelected = true),
            onTeacherTap: () => setState(() => isStudentSelected = false),
          ),
          const SizedBox(height: 24),
          LoginForm(
            isStudentSelected: isStudentSelected,
            isLoading: _isLoading, // Pass loading state
            idController: _emailController,
            passwordController: _passwordController,
            onLoginPressed: _handleLogin, // Call the async login function
            onForgotPassword: () {},
          ),
        ],
      ),
    );
  }
}

/// ===============================
///  LOGIN FORM WIDGET
/// ===============================
class LoginForm extends StatelessWidget {
  final bool isStudentSelected;
  final bool isLoading; // Added to handle UI state
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
        // EMAIL FIELD
        TextField(
          controller: idController,
          keyboardType: TextInputType.emailAddress,
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

        // PASSWORD FIELD
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

        // LOGIN BUTTON (WITH LOADING STATE)
        SizedBox(
          width: double.infinity,
          height: 50, // Fixed height to prevent resizing on spinner
          child: ElevatedButton(
            onPressed: isLoading ? null : onLoginPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'LOGIN',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),

        TextButton(
          onPressed: onForgotPassword,
          child: Text(
            'Forgot Password?',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(color: Colors.grey.shade300, thickness: 1),
        ),

        // REGISTRATION BUTTONS
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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
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
///  LOGIN TOGGLE WIDGET
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
    const Color primaryBlue = SmartAttendanceScreen.primaryBlue;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          _buildToggleOption(
            "STUDENT LOGIN",
            isStudentSelected,
            onStudentTap,
            primaryBlue,
          ),
          _buildToggleOption(
            "TEACHER LOGIN",
            !isStudentSelected,
            onTeacherTap,
            primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(
    String title,
    bool isSelected,
    VoidCallback onTap,
    Color activeColor,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

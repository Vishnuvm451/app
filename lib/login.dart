import 'package:darzo/dashboard/admin_panel.dart';
import 'package:darzo/teacher/attendance.dart';
import 'package:flutter/material.dart';
import 'package:darzo/dashboard/student_dashboard.dart';
import 'package:darzo/dashboard/teacher_dashboard.dart';
import 'package:darzo/students/student_reg.dart';
import 'package:darzo/teacher/teacher_reg.dart';

import 'package:darzo/teacher/internal_mark.dart';
import 'package:darzo/demo.dart';

/// ===============================
///  ROOT APP
/// ===============================
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF2196F3),
      ),
      home: const SmartAttendanceScreen(),
    );
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminDashboardPage()),
                );
              },
              icon: Icon(Icons.admin_panel_settings_outlined, size: 50),
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

        // demo test start
        Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttendanceDailyPage(),
                ),
              );
            },
            child: Text("Button"),
          ),
        ),

        // demo test end
        // Title text
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

        // Logo (simple circular icon)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // ignore: deprecated_member_use
            color: Colors.white.withOpacity(0.18),
          ),
          child: const Icon(Icons.access_time, size: 56, color: Colors.white),
        ),
      ],
    );
  }
}

/// ===============================
///  LOGIN CARD (WHITE ROUNDED BOX)
/// ===============================
class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  /// true  = Student login selected
  /// false = Teacher login selected
  bool isStudentSelected = true;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
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
          /// ---------------------------
          /// TOGGLE: STUDENT / TEACHER
          /// ---------------------------
          LoginToggle(
            isStudentSelected: isStudentSelected,
            onStudentTap: () {
              setState(() {
                isStudentSelected = true;
              });
            },
            onTeacherTap: () {
              setState(() {
                isStudentSelected = false;
              });
            },
          ),

          const SizedBox(height: 24),

          /// ---------------------------
          /// LOGIN FORM
          /// ---------------------------
          LoginForm(
            isStudentSelected: isStudentSelected,
            idController: _idController,
            passwordController: _passwordController,
            onLoginPressed: () {
              // For now just print. Replace with your logic.
              debugPrint(
                'Login as ${isStudentSelected ? "Student" : "Teacher"}',
              );
              debugPrint('ID: ${_idController.text}');
              debugPrint('Password: ${_passwordController.text}');
            },
            onForgotPassword: () {
              debugPrint('Forgot password tapped');
            },
            onRegisterNow: () {
              debugPrint('Register now tapped');
            },
          ),
        ],
      ),
    );
  }
}

/// ===============================
///  LOGIN TOGGLE WIDGET
///  (STUDENT LOGIN / TEACHER LOGIN)
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
          // STUDENT TAB
          Expanded(
            child: GestureDetector(
              onTap: onStudentTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isStudentSelected ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                alignment: Alignment.center,
                child: Text(
                  'STUDENT LOGIN',
                  style: TextStyle(
                    color: isStudentSelected
                        ? Colors.white
                        : Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: isStudentSelected
                        ? FontWeight.bold
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),

          // TEACHER TAB
          Expanded(
            child: GestureDetector(
              onTap: onTeacherTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !isStudentSelected ? primaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                alignment: Alignment.center,
                child: Text(
                  'TEACHER LOGIN',
                  style: TextStyle(
                    color: !isStudentSelected
                        ? Colors.white
                        : Colors.grey.shade700,
                    fontSize: 12,
                    fontWeight: !isStudentSelected
                        ? FontWeight.bold
                        : FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
///  LOGIN FORM WIDGET
///  (TEXTFIELDS + BUTTONS)
/// ===============================
class LoginForm extends StatelessWidget {
  final bool isStudentSelected;
  final TextEditingController idController;
  final TextEditingController passwordController;
  final VoidCallback onLoginPressed;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegisterNow;

  const LoginForm({
    super.key,
    required this.isStudentSelected,
    required this.idController,
    required this.passwordController,
    required this.onLoginPressed,
    required this.onForgotPassword,
    required this.onRegisterNow,
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = SmartAttendanceScreen.primaryBlue;

    return Column(
      children: [
        /// ID FIELD (Student ID / Teacher ID based on toggle)
        TextField(
          controller: idController,
          decoration: InputDecoration(
            labelText: isStudentSelected ? 'Email ID' : 'Teacher ID',
            prefixIcon: Icon(
              isStudentSelected ? Icons.school : Icons.person_outline,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryBlue),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
          ),
        ),

        const SizedBox(height: 16),

        /// PASSWORD FIELD
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
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFF1976D2), width: 2),
            ),
          ),
        ),

        const SizedBox(height: 24),

        /// LOGIN BUTTON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onLoginPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'LOGIN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        /// FORGOT PASSWORD
        TextButton(
          onPressed: onForgotPassword,
          child: Text(
            'Forgot Password?',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),

        /// DIVIDER
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Divider(color: Colors.grey.shade300, thickness: 1),
        ),

        /// REGISTER AS STUDENT BUTTON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StudentRegisterPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'REGISTER AS STUDENT',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // REGISTER AS TEACHER BUTTON
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TeacherRegisterPage(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'REGISTER AS TEACHER',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

// login.dart
// Login page with Firebase Authentication + Firestore role check (student/teacher).
// Make sure: firebase_core is initialized in main.dart and packages are added in pubspec.yaml.

import 'package:darzo/register/student_reg.dart';
import 'package:darzo/register/teacher_reg.dart';
import 'package:flutter/material.dart';

// ADDED: Firebase imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// ===============================
///  ROOT LOGIN PAGE
/// ===============================
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    // CHANGED: Removed nested MaterialApp.
    // The real MaterialApp is already in main.dart.
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
///  HEADER: TITLE + LOGO
/// ===============================
class HeaderSection extends StatelessWidget {
  const HeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),

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

  // ADDED: Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ADDED: loading state for login button
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ADDED: login handler (Auth + Firestore check)
  Future<void> _handleLogin() async {
    final idText = _idController.text.trim();
    final password = _passwordController.text;

    // Basic validation
    if (idText.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter ID and password')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // NOTE: Currently using email + password for both student & teacher.
      // For teachers, make sure their "ID" is actually an email in Firebase Auth,
      // OR change logic later to handle real teacher IDs.
      final UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: idText,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'NO_USER',
          message: 'Login failed. Try again.',
        );
      }

      final uid = user.uid;

      if (isStudentSelected) {
        // ADDED: verify student document in Firestore
        final doc = await _firestore.collection('students').doc(uid).get();

        if (!doc.exists) {
          // No student doc → sign out and show error
          await _auth.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No student record found for this account'),
            ),
          );
          return;
        }

        // TODO: Navigate to Student Dashboard here
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student login successful')),
        );
      } else {
        // TEACHER LOGIN:
        // For now, just Auth login. You can later:
        // - create "teachers" collection
        // - check Firestore like we did for students.
        // Example (commented):
        //
        // final doc = await _firestore.collection('teachers').doc(uid).get();
        // if (!doc.exists) { ... }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Teacher login successful')),
        );

        // TODO: Navigate to Teacher Dashboard here
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found for this email';
      } else if (e.code == 'wrong-password') {
        message = 'Wrong password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.message != null) {
        message = e.message!;
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
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
            // CHANGED: call our login logic instead of just debugPrint
            onLoginPressed: _handleLogin,
            onForgotPassword: () {
              // TODO: Add forgot password (send reset email)
              debugPrint('Forgot password tapped');
            },
            onRegisterNow: () {
              debugPrint('Register now tapped');
            },
            // ADDED: pass loading state to disable button + show spinner
            isLoading: _isLoading,
          ),
        ],
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

  // ADDED: loading flag to control button
  final bool isLoading;

  const LoginForm({
    super.key,
    required this.isStudentSelected,
    required this.idController,
    required this.passwordController,
    required this.onLoginPressed,
    required this.onForgotPassword,
    required this.onRegisterNow,
    this.isLoading = false, // default false
  });

  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = SmartAttendanceScreen.primaryBlue;

    return Column(
      children: [
        /// ID FIELD (Student ID / Teacher ID based on toggle)
        TextField(
          controller: idController,
          keyboardType: isStudentSelected
              ? TextInputType.emailAddress
              : TextInputType.text,
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
          decoration: const InputDecoration(
            labelText: 'Password',
            prefixIcon: Icon(Icons.lock_outline),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: primaryBlue),
            ),
            focusedBorder: OutlineInputBorder(
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
            onPressed: isLoading ? null : onLoginPressed,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
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

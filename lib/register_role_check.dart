import 'package:darzo/login.dart';
import 'package:darzo/parents/parents_register.dart';
import 'package:darzo/student/student_register.dart';
import 'package:darzo/teacher/teacher_register.dart';
import 'package:flutter/material.dart';

class RegisterRoleCheck extends StatelessWidget {
  const RegisterRoleCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 8.0),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, size: 35, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 25),
              const Icon(Icons.school, size: 100, color: Colors.white),
              const SizedBox(height: 25),
              const Text(
                "DARZO",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'REGISTER AS',
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.blue,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 50),

                      // Student Button
                      _registerButton("STUDENT", () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudentRegisterPage(),
                          ),
                        );
                      }),

                      const SizedBox(height: 20),

                      // Teacher Button
                      _registerButton(
                        "TEACHER",
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TeacherRegisterPage(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Parent Button
                      _registerButton(
                        "PARENT",
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ParentRegisterPage(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
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

  // Fixed typo in method name: _registerButton
  Widget _registerButton(String title, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 50, // Increased height slightly for better touch target
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

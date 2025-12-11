// student_register.dart
// Student registration page with Firebase Auth + Firestore integration.
// Replace your existing StudentRegisterPage with this file.
// Make sure firebase_core is initialized in main.dart before using this page.

import 'package:darzo/login/login.dart';
import 'package:flutter/material.dart';

// ADDED: Firebase packages
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  // ─────────────────────────────────────────────
  // TEXT CONTROLLERS
  // ─────────────────────────────────────────────
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController admissionController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Dropdown values
  String? selectedDepartment;
  String? selectedYear;

  // Loading state for register button
  bool _isLoading = false;

  // ─────────────────────────────────────────────
  // DEPARTMENT LIST + DEPARTMENT -> YEARS MAP
  // ─────────────────────────────────────────────
  final List<String> departments = [
    "Department",
    "Computer Science",
    "Physics",
    "BCom",
  ];

  final Map<String, List<String>> deptToYears = {
    "Computer Science": ["CS1", "CS2", "CS3", "PG1", "PG2"],
    "Physics": ["PHY1", "PHY2", "PHY3", "PG1", "PG2"],
    "BCom": ["BCOM1", "BCOM2", "BCOM3", "MCOM1", "MCOM2"],
  };

  List<String> get currentYearOptions {
    if (selectedDepartment == null) return <String>[];
    return deptToYears[selectedDepartment!] ?? <String>[];
  }

  // ─────────────────────────────────────────────
  // FIREBASE INSTANCES (ADDED)
  // ─────────────────────────────────────────────
  final FirebaseAuth _auth = FirebaseAuth.instance; // ADDED: Firebase Auth
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // ADDED: Firestore

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    admissionController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // REGISTER: Validate -> Create Auth user -> Save to Firestore
  // ─────────────────────────────────────────────
  Future<void> _registerStudent() async {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final department = selectedDepartment;
    final year = selectedYear;

    // Basic validation (UI-only)
    if (fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        department == null ||
        year == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ADDED: create user with Firebase Auth
      final UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'NO_USER',
          message: 'Failed to create user',
        );
      }

      final uid = user.uid;

      // ADDED: Save student details in Firestore under 'students' collection
      await _firestore.collection('students').doc(uid).set({
        'uid': uid,
        'fullName': fullName,
        'email': email,
        'department': department,
        'year': year,
        'admissionNumber': admissionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Success - show message and navigate to Login (or dashboard)
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registration successful')));

      // Navigate back to login page (replace or pop)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      // Handle auth errors clearly
      String message = 'Registration failed';
      if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email already in use';
      } else if (e.message != null) {
        message = e.message!;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      // Generic error
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
    const Color primaryBlue = Color(0xFF2196F3);

    return Scaffold(
      backgroundColor: primaryBlue,

      // Safe area + scroll view
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),

            child: Column(
              children: [
                // ─────────────────────
                // APP TITLE
                // ─────────────────────
                const Text(
                  "DARZO",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 20),

                // Icon Circle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    size: 56,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 30),

                // ─────────────────────
                // CARD (White Box)
                // ─────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Title
                      const Text(
                        "STUDENT REGISTRATION",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ───────────────────────────────
                      // FULL NAME FIELD
                      // ───────────────────────────────
                      _buildTextField(
                        controller: fullNameController,
                        label: "Full Name",
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 15),

                      // EMAIL FIELD
                      _buildTextField(
                        controller: emailController,
                        label: "Email ID",
                        icon: Icons.school,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 15),

                      // ───────────────────────────────
                      // DEPARTMENT DROPDOWN
                      // ───────────────────────────────
                      _buildDropdown(
                        value: selectedDepartment,
                        label: "Department",
                        items: departments,
                        icon: Icons.account_balance_outlined,
                        onChanged: (value) {
                          // When department changes, reset selectedYear so user must re-pick
                          setState(() {
                            selectedDepartment = value;
                            selectedYear = null;
                          });
                        },
                      ),
                      const SizedBox(height: 15),

                      // ───────────────────────────────
                      // YEAR DROPDOWN (Dynamic based on department)
                      // ───────────────────────────────
                      DropdownButtonFormField<String>(
                        value: selectedYear,
                        decoration: InputDecoration(
                          labelText: selectedDepartment == null
                              ? "Select Department first"
                              : "Year",
                          prefixIcon: const Icon(Icons.bookmark_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        // If no department selected, present empty list
                        items: currentYearOptions
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedYear = value;
                          });
                        },
                      ),
                      const SizedBox(height: 15),

                      // PASSWORD FIELD
                      _buildTextField(
                        controller: passwordController,
                        label: "Password",
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),

                      const SizedBox(height: 25),

                      // ───────────────────────────────
                      // REGISTER BUTTON (now calls Firebase code)
                      // ───────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _registerStudent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    // color not specified to respect theme defaults
                                  ),
                                )
                              : const Text(
                                  "REGISTER",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Already have account?
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? "),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                color: primaryBlue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────
  // TEXT FIELD BUILDER (Reusable)
  // ───────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ───────────────────────────────
  // DROPDOWN BUILDER (Reusable)
  // ───────────────────────────────
  Widget _buildDropdown({
    required String? value,
    required String label,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

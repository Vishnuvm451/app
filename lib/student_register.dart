import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  // ---------------- CONTROLLERS ----------------
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController admissionController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // ---------------- STATE ----------------
  String? selectedDeptId;
  String? selectedDeptName;

  String? selectedClassId;
  String? selectedClassName;

  String? selectedCourseType;
  final List<String> courseTypes = ['UG', 'PG'];

  bool isLoading = false;
  bool _isPasswordVisible = false; // 👁 PASSWORD TOGGLE

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    admissionController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ======================================================
  // REGISTER STUDENT
  // ======================================================
  Future<void> registerStudent() async {
    if (fullNameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        admissionController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        selectedDeptId == null ||
        selectedClassId == null ||
        selectedCourseType == null) {
      _showSnack("Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1️⃣ CREATE AUTH USER
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2️⃣ SAVE USER + STUDENT PROFILE
      await FirebaseFirestore.instance.runTransaction((tx) async {
        // USERS
        tx.set(FirebaseFirestore.instance.collection('users').doc(uid), {
          'uid': uid,
          'name': fullNameController.text.trim(),
          'email': emailController.text.trim(),
          'role': 'student',
          'created_at': FieldValue.serverTimestamp(),
        });

        // STUDENTS
        tx.set(FirebaseFirestore.instance.collection('students').doc(uid), {
          'uid': uid,
          'name': fullNameController.text.trim(),
          'email': emailController.text.trim(),
          'register_number': admissionController.text.trim(),
          'departmentId': selectedDeptId,
          'departmentName': selectedDeptName,
          'classId': selectedClassId,
          'className': selectedClassName,
          'courseType': selectedCourseType,
          'face_enabled': false,
          'created_at': FieldValue.serverTimestamp(),
        });
      });

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      _showSnack("Student registered successfully", success: true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Registration failed");
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF2196F3);

    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  "DARZO",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 30),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "STUDENT REGISTRATION",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _field(
                        fullNameController,
                        "Full Name",
                        Icons.person_outline,
                      ),
                      _field(
                        admissionController,
                        "Admission Number",
                        Icons.badge_outlined,
                      ),
                      _field(
                        emailController,
                        "Email",
                        Icons.email_outlined,
                        formatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                      ),

                      // 🔐 PASSWORD WITH 👁 BUTTON
                      TextField(
                        controller: passwordController,
                        obscureText: !_isPasswordVisible,
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // ---------------- DEPARTMENT ----------------
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('departments')
                            .orderBy('name')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const LinearProgressIndicator();
                          }

                          final docs = snapshot.data!.docs;

                          return DropdownButtonFormField<String>(
                            value: selectedDeptId,
                            decoration: const InputDecoration(
                              labelText: "Department",
                              prefixIcon: Icon(Icons.account_balance_outlined),
                            ),
                            items: docs
                                .map(
                                  (d) => DropdownMenuItem<String>(
                                    value: d.id,
                                    child: Text(d['name']),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                selectedDeptId = val;
                                selectedDeptName = docs.firstWhere(
                                  (d) => d.id == val,
                                )['name'];
                                selectedClassId = null;
                                selectedCourseType = null;
                              });
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 15),

                      // ---------------- COURSE TYPE ----------------
                      DropdownButtonFormField<String>(
                        value: selectedCourseType,
                        decoration: const InputDecoration(
                          labelText: "Course Type",
                          prefixIcon: Icon(Icons.school_outlined),
                        ),
                        items: courseTypes
                            .map(
                              (t) => DropdownMenuItem<String>(
                                value: t,
                                child: Text(t),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedCourseType = val;
                            selectedClassId = null;
                          });
                        },
                      ),

                      const SizedBox(height: 15),

                      // ---------------- CLASS ----------------
                      if (selectedDeptId != null && selectedCourseType != null)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('classes')
                              .where('departmentId', isEqualTo: selectedDeptId)
                              .where('type', isEqualTo: selectedCourseType)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const LinearProgressIndicator();
                            }

                            final docs = snapshot.data!.docs;

                            return DropdownButtonFormField<String>(
                              value: selectedClassId,
                              decoration: const InputDecoration(
                                labelText: "Class",
                                prefixIcon: Icon(Icons.class_outlined),
                              ),
                              items: docs
                                  .map(
                                    (d) => DropdownMenuItem<String>(
                                      value: d.id,
                                      child: Text(d['name']),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedClassId = val;
                                  selectedClassName = docs.firstWhere(
                                    (d) => d.id == val,
                                  )['name'];
                                });
                              },
                            );
                          },
                        ),

                      const SizedBox(height: 25),

                      // ---------------- REGISTER BUTTON ----------------
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : registerStudent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
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

                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
                            ),
                          );
                        },
                        child: const Text(
                          "Already have an account? Login",
                          style: TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

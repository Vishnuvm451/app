// lib/teacher/teacher_register.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/login.dart';

class TeacherRegisterPage extends StatefulWidget {
  const TeacherRegisterPage({super.key});

  @override
  State<TeacherRegisterPage> createState() => _TeacherRegisterPageState();
}

class _TeacherRegisterPageState extends State<TeacherRegisterPage> {
  // ---------------- CONTROLLERS ----------------
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // ---------------- DROPDOWN ----------------
  final List<String> departments = ["Computer Science", "Physics", "BCom"];
  String? selectedDepartment;

  bool isLoading = false;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ======================================================
  // REGISTER TEACHER (AFTER ADMIN APPROVAL)
  // ======================================================
  Future<void> registerTeacher() async {
    if (fullNameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty ||
        selectedDepartment == null) {
      _showDialog("Error", "Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      final email = emailController.text.trim();

      // 🔍 Check if request exists
      final requestQuery = await FirebaseFirestore.instance
          .collection("teacher_requests")
          .where("email", isEqualTo: email)
          .limit(1)
          .get();

      // 🟡 FIRST TIME → CREATE REQUEST
      if (requestQuery.docs.isEmpty) {
        await FirebaseFirestore.instance.collection("teacher_requests").add({
          "name": fullNameController.text.trim(),
          "email": email,
          "department": selectedDepartment,
          "status": "pending",
          "created_at": FieldValue.serverTimestamp(),
        });

        _showDialog(
          "Request Sent",
          "Your request has been sent to admin.\nPlease wait for approval.",
        );
        return;
      }

      final requestDoc = requestQuery.docs.first;
      final status = requestDoc['status'];

      // 🟠 PENDING
      if (status == "pending") {
        _showDialog(
          "Pending Approval",
          "Your request is still under review by admin.",
        );
        return;
      }

      // 🔴 REJECTED
      if (status == "rejected") {
        _showDialog("Rejected", "Your request was rejected by admin.");
        return;
      }

      // 🟢 APPROVED → REGISTER
      if (status == "approved") {
        // Create Auth user
        UserCredential cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: email,
              password: passwordController.text.trim(),
            );

        final uid = cred.user!.uid;

        // users/{uid}
        await FirebaseFirestore.instance.collection("users").doc(uid).set({
          "uid": uid,
          "name": fullNameController.text.trim(),
          "email": email,
          "role": "teacher",
          "created_at": FieldValue.serverTimestamp(),
        });

        // teachers/{uid}
        await FirebaseFirestore.instance.collection("teachers").doc(uid).set({
          "uid": uid,
          "name": fullNameController.text.trim(),
          "email": email,
          "department": selectedDepartment,
          "created_at": FieldValue.serverTimestamp(),
        });

        // mark registered
        await requestDoc.reference.update({
          "is_registered": true,
          "registered_at": FieldValue.serverTimestamp(),
        });

        _showDialog(
          "Success",
          "Account created successfully.\nYou can now login.",
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      _showDialog("Error", e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------- DIALOG HELPER ----------------
  Future<void> _showDialog(String title, String message) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
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
                const SizedBox(height: 12),
                const Text(
                  "DARZO",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.18),
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),

                // WHITE CARD
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "TEACHER REGISTRATION",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildTextField(
                        controller: fullNameController,
                        label: "Full Name",
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 14),

                      _buildTextField(
                        controller: emailController,
                        label: "Email ID",
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<String>(
                        value: selectedDepartment,
                        decoration: InputDecoration(
                          labelText: "Department",
                          prefixIcon: const Icon(Icons.apartment_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: departments
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedDepartment = value),
                      ),
                      const SizedBox(height: 14),

                      _buildTextField(
                        controller: passwordController,
                        label: "Password",
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),
                      const SizedBox(height: 22),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : registerTeacher,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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

                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? "),
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

  // ---------------- TEXT FIELD ----------------
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/login.dart';

class TeacherRegisterPage extends StatefulWidget {
  const TeacherRegisterPage({super.key});

  @override
  State<TeacherRegisterPage> createState() => _TeacherRegisterPageState();
}

class _TeacherRegisterPageState extends State<TeacherRegisterPage> {
  // ---------------- CONTROLLERS ----------------
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // ---------------- STATE ----------------
  String? selectedDeptId;
  String? selectedDeptName;

  bool isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ======================================================
  // TEACHER REGISTER -> REQUEST ONLY (NO EMAIL VERIFICATION)
  // ======================================================
  Future<void> registerTeacher() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        selectedDeptId == null) {
      _showSnack("Please fill all fields");
      return;
    }

    if (passwordController.text.length < 6) {
      _showSnack("Password must be at least 6 characters");
      return;
    }

    final email = emailController.text.trim().toLowerCase();
    setState(() => isLoading = true);

    UserCredential? cred;

    try {
      // 1. CREATE AUTH USER
      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: passwordController.text,
      );

      final uid = cred.user!.uid;

      // 2. CREATE TEACHER REQUEST (ADMIN APPROVAL ONLY)
      await FirebaseFirestore.instance.collection('teacher_request').add({
        'authUid': uid,
        'name': nameController.text.trim(),
        'email': email,
        'departmentId': selectedDeptId,
        'departmentName': selectedDeptName,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnack(
        "Request submitted successfully.\nWait for admin approval.",
        success: true,
      );

      // 3. SIGN OUT (PREVENT LOGIN BEFORE APPROVAL)
      await FirebaseAuth.instance.signOut();

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Registration failed";
      if (e.code == 'email-already-in-use') {
        msg = "Email is already registered.";
      } else if (e.code == 'weak-password') {
        msg = "Password is too weak.";
      } else if (e.code == 'invalid-email') {
        msg = "Invalid email format.";
      }
      _showSnack(msg);
    } catch (e) {
      // Rollback auth user if Firestore fails
      if (cred?.user != null) {
        await cred!.user!.delete();
      }
      _showSnack("Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ======================================================
  // UI (UNCHANGED)
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
                        "TEACHER REGISTRATION",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _field(nameController, "Full Name", Icons.person_outline),

                      _field(
                        emailController,
                        "Email",
                        Icons.email_outlined,
                        blockSpaces: true,
                      ),

                      TextField(
                        controller: passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
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

                      // DEPARTMENT DROPDOWN
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('department')
                            .orderBy('name')
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 15),
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = snapshot.data!.docs;

                          return DropdownButtonFormField<String>(
                            value: selectedDeptId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: "Department",
                              prefixIcon: Icon(Icons.account_balance_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(14),
                                ),
                              ),
                            ),
                            items: docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(data['name'] ?? "Unnamed"),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                selectedDeptId = val;
                                final doc = docs.firstWhere((d) => d.id == val);
                                selectedDeptName =
                                    (doc.data()
                                        as Map<String, dynamic>)['name'];
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 25),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : registerTeacher,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "SUBMIT REQUEST",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Already have an account? "),
                          TextButton(
                            onPressed: isLoading
                                ? null
                                : () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const LoginPage(),
                                      ),
                                    );
                                  },
                            child: const Text(
                              "Login",
                              style: TextStyle(fontWeight: FontWeight.bold),
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

  // ---------------- TEXT FIELD HELPER ----------------
  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool blockSpaces = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        inputFormatters: blockSpaces
            ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))]
            : [],
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

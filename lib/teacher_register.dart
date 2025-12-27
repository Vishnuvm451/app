import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'login.dart';

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
  // CHECK DUPLICATES (EMAIL)
  // ======================================================
  Future<bool> _emailAlreadyExists(String email) async {
    final db = FirebaseFirestore.instance;

    // 1. Check Requests
    final requestSnap = await db
        .collection('teacher_requests')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (requestSnap.docs.isNotEmpty) return true;

    // 2. Check Existing Teachers
    final teacherSnap = await db
        .collection('teachers') // Fixed collection name: 'teachers' (plural)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (teacherSnap.docs.isNotEmpty) return true;

    // 3. Check Users Collection
    final userSnap = await db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (userSnap.docs.isNotEmpty) return true;

    return false;
  }

  // ======================================================
  // TEACHER REGISTER (REQUEST -> ADMIN APPROVAL)
  // ======================================================
  Future<void> registerTeacher() async {
    if (nameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        selectedDeptId == null) {
      _showSnack("Please fill all fields");
      return;
    }

    // Basic Password Strength Check
    if (passwordController.text.length < 6) {
      _showSnack("Password must be at least 6 characters");
      return;
    }

    final email = emailController.text.trim().toLowerCase();

    setState(() => isLoading = true);

    try {
      // 🔐 DUPLICATE CHECK
      final exists = await _emailAlreadyExists(email);

      if (exists) {
        _showSnack("This email is already registered or pending approval");
        setState(() => isLoading = false);
        return;
      }

      // ✅ CREATE REQUEST
      await FirebaseFirestore.instance.collection('teacher_requests').add({
        'name': nameController.text.trim(),
        'email': email,
        'password': passwordController
            .text, // Warning: Storing plain text password for approval flow
        'departmentId': selectedDeptId,
        'departmentName': selectedDeptName,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showSnack(
        "Registration request sent.\nWait for admin approval.",
        success: true,
      );

      // Delay slightly for UX before navigating
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
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
        behavior: SnackBarBehavior.floating,
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
                        "TEACHER REGISTRATION",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _field(nameController, "Full Name", Icons.person_outline),

                      // Email: Block Spaces
                      _field(
                        emailController,
                        "Email",
                        Icons.email_outlined,
                        blockSpaces: true,
                      ),

                      // 🔐 PASSWORD WITH 👁 (Allow Spaces)
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

                      // ---------------- DEPARTMENT DROPDOWN (FIXED) ----------------
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('departments')
                            .orderBy('name')
                            .snapshots(),
                        builder: (context, snapshot) {
                          // 1. Error Handling
                          if (snapshot.hasError) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                "Error: Check Firestore Rules! \n${snapshot.error}",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }

                          // 2. Loading State
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 15),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          // 3. Empty State
                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(15),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text(
                                "No departments available.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          // 4. Dropdown
                          return DropdownButtonFormField<String>(
                            value: selectedDeptId,
                            isExpanded: true, // Prevents overflow
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
                              final name = data['name'] ?? "Unnamed";
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                selectedDeptId = val;
                                try {
                                  final doc = docs.firstWhere(
                                    (d) => d.id == val,
                                  );
                                  selectedDeptName =
                                      (doc.data()
                                          as Map<String, dynamic>)['name'];
                                } catch (_) {
                                  selectedDeptName = "Unknown";
                                }
                              });
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 25),

                      // ---------------- SUBMIT ----------------
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

  // Helper Widget for TextFields
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
        // Only block spaces if explicitly requested (like for Email)
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

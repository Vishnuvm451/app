import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  // ---------------- CONTROLLERS ----------------
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _admissionCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _classCtrl = TextEditingController();

  // ---------------- STATE ----------------
  String? selectedDepartmentId;
  bool isLoading = false;
  bool showPassword = false;

  final Color primaryBlue = const Color(0xFF2196F3);

  // ======================================================
  // REGISTER STUDENT
  // ======================================================
  Future<void> _registerStudent() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _admissionCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty ||
        _classCtrl.text.trim().isEmpty ||
        selectedDepartmentId == null) {
      _showSnack("Please fill all fields");
      return;
    }

    try {
      setState(() => isLoading = true);

      // 1️⃣ CREATE AUTH USER
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2️⃣ CREATE USER ROLE
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'email': _emailCtrl.text.trim(),
        'role': 'student',
        'created_at': FieldValue.serverTimestamp(),
      });

      // 3️⃣ CREATE STUDENT PROFILE
      await FirebaseFirestore.instance.collection('students').doc(uid).set({
        'uid': uid,
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'admissionNo': _admissionCtrl.text.trim(),
        'departmentId': selectedDepartmentId,
        'class': _classCtrl.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });

      _showSnack("Registration successful", success: true);

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
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
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "STUDENT REGISTRATION",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // FULL NAME (ALLOW SPACES)
                      _inputField(
                        controller: _nameCtrl,
                        hint: "Full Name",
                        icon: Icons.person,
                        blockSpaces: false,
                      ),

                      // EMAIL (NO SPACES)
                      _inputField(
                        controller: _emailCtrl,
                        hint: "Email ID",
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        blockSpaces: true,
                      ),

                      // ADMISSION NUMBER (NO SPACES)
                      _inputField(
                        controller: _admissionCtrl,
                        hint: "Admission Number",
                        icon: Icons.badge,
                        blockSpaces: true,
                      ),

                      // DEPARTMENT DROPDOWN
                      _departmentDropdown(),

                      // CLASS (NO SPACES)
                      _inputField(
                        controller: _classCtrl,
                        hint: "Class",
                        icon: Icons.school,
                        blockSpaces: true,
                      ),

                      // PASSWORD
                      _passwordField(),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _registerStudent,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
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

                      const SizedBox(height: 12),

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
                            child: Text(
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

  // ======================================================
  // WIDGETS
  // ======================================================
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    required bool blockSpaces,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: blockSpaces
            ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))]
            : null,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: _passwordCtrl,
        obscureText: !showPassword,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        decoration: InputDecoration(
          hintText: "Password",
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() => showPassword = !showPassword);
            },
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _departmentDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('departments')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Text(
              "No departments available. Contact admin.",
              style: TextStyle(color: Colors.red),
            );
          }

          return DropdownButtonFormField<String>(
            value: selectedDepartmentId,
            hint: const Text("Department"),
            items: snapshot.data!.docs.map((doc) {
              return DropdownMenuItem<String>(
                value: doc.id,
                child: Text(doc['name']),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => selectedDepartmentId = val);
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.account_balance),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

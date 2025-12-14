import 'package:darzo/login.dart';
import 'package:flutter/material.dart';

// 🔥 Firebase imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  // -------------------------------
  // TEXT CONTROLLERS
  // -------------------------------
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController admissionController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // -------------------------------
  // DROPDOWN VALUES
  // -------------------------------
  String? selectedDepartment;
  String? selectedYear;

  final List<String> departments = ["Computer Science", "Physics", "BCom"];

  final Map<String, List<String>> deptToYears = {
    "Computer Science": ["CS1", "CS2", "CS3", "PG1", "PG2"],
    "Physics": ["PHY1", "PHY2", "PHY3", "PG1", "PG2"],
    "BCom": ["BCOM1", "BCOM2", "BCOM3", "MCOM1", "MCOM2"],
  };

  bool isLoading = false;

  List<String> get currentYearOptions {
    if (selectedDepartment == null) return [];
    return deptToYears[selectedDepartment!] ?? [];
  }

  // -------------------------------
  // 🔥 FIREBASE REGISTRATION LOGIC
  // -------------------------------
  Future<void> registerStudent() async {
    // BASIC VALIDATION
    if (fullNameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        admissionController.text.trim().isEmpty ||
        passwordController.text.trim().isEmpty ||
        selectedDepartment == null ||
        selectedYear == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1️⃣ CREATE AUTH USER
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final String uid = cred.user!.uid;

      // 2️⃣ ATOMIC FIRESTORE WRITE
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // COMMON USERS COLLECTION (ROLE BASED LOGIN)
        transaction
            .set(FirebaseFirestore.instance.collection('users').doc(uid), {
              "uid": uid,
              "name": fullNameController.text.trim(),
              "email": emailController.text.trim(),
              "role": "student",
              "created_at": FieldValue.serverTimestamp(),
            });

        // STUDENT SPECIFIC DATA
        transaction
            .set(FirebaseFirestore.instance.collection('students').doc(uid), {
              "uid": uid,
              "admission_no": admissionController.text.trim(),
              "department": selectedDepartment,
              "year": selectedYear,
              "face_enabled": false,
            });
      });

      // 3️⃣ LOGOUT AFTER REGISTRATION (SAFE PRACTICE)
      await FirebaseAuth.instance.signOut();

      // 4️⃣ GO TO LOGIN
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Registration failed")),
      );
    } catch (e) {
      // SAFETY CLEANUP
      await FirebaseAuth.instance.currentUser?.delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Something went wrong")));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // -------------------------------
  // UI
  // -------------------------------
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
                  width: double.infinity,
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

                      _buildTextField(
                        controller: fullNameController,
                        label: "Full Name",
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 15),

                      _buildTextField(
                        controller: emailController,
                        label: "Email ID",
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 15),

                      _buildTextField(
                        controller: admissionController,
                        label: "Admission Number",
                        icon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 15),

                      _buildDropdown(
                        value: selectedDepartment,
                        label: "Department",
                        items: departments,
                        icon: Icons.account_balance_outlined,
                        onChanged: (value) {
                          setState(() {
                            selectedDepartment = value;
                            selectedYear = null;
                          });
                        },
                      ),
                      const SizedBox(height: 15),

                      DropdownButtonFormField<String>(
                        value: selectedYear,
                        decoration: InputDecoration(
                          labelText: "Year",
                          prefixIcon: const Icon(Icons.bookmark_outline),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        items: currentYearOptions
                            .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedYear = value);
                        },
                      ),
                      const SizedBox(height: 15),

                      _buildTextField(
                        controller: passwordController,
                        label: "Password",
                        icon: Icons.lock_outline,
                        obscure: true,
                      ),
                      const SizedBox(height: 25),

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

  // -------------------------------
  // REUSABLE WIDGETS
  // -------------------------------
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

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

  // -------------------------------
  // CLEANUP
  // -------------------------------
  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    admissionController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}

import 'package:darzo/login.dart';
// import 'package:darzo/face_capture.dart'; // <--- UNCOMMENT FOR FACE CAPTURE
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  // ================= CONTROLLERS =================
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _admissionCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // ================= STATE =================
  String? selectedDepartmentId;
  String? selectedClassId;
  bool isLoading = false;
  bool showPassword = false;

  final Color primaryBlue = const Color(0xFF2196F3);

  // ❌ No spaces for email & password
  final List<TextInputFormatter> _noSpaceFormatter = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
  ];

  // ================= FIREBASE =================
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _admissionCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // REGISTER STUDENT (FINAL FIXED VERSION)
  // ======================================================
  Future<void> _registerStudent() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _admissionCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty ||
        selectedDepartmentId == null ||
        selectedClassId == null) {
      _showSnack("Please fill all fields");
      return;
    }

    if (_passwordCtrl.text.length < 6) {
      _showSnack("Password must be at least 6 characters");
      return;
    }

    try {
      setState(() => isLoading = true);

      // 1. Check if Class Exists (Data Integrity)
      final classSnap = await _db
          .collection('classes')
          .doc(selectedClassId)
          .get();
      if (!classSnap.exists) {
        _showSnack("Selected class no longer exists");
        setState(() => isLoading = false);
        return;
      }
      final classData = classSnap.data()!;

      // 2. Prevent duplicate admission number
      final existing = await _db
          .collection('students')
          .where('admissionNo', isEqualTo: _admissionCtrl.text.trim())
          .get();

      if (existing.docs.isNotEmpty) {
        _showSnack("Admission number already exists");
        setState(() => isLoading = false);
        return;
      }

      // 3. Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // 4. USERS (ROLE MASTER)
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': _emailCtrl.text.trim(),
        'role': 'student',
        'created_at': FieldValue.serverTimestamp(),
      });

      // 5. STUDENTS (PROFILE)
      await _db.collection('students').doc(uid).set({
        'uid': uid,
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'admissionNo': _admissionCtrl.text.trim(),
        'departmentId': selectedDepartmentId,
        'classId': selectedClassId,
        'courseType': classData['courseType'] ?? 'UG',
        'year': classData['year'] ?? 1,
        'face_enabled': false, // Default
        'created_at': FieldValue.serverTimestamp(),
      });

      _showSnack("Registration successful", success: true);

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      // ---------------- NAVIGATION ----------------
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );

      /* // 🔥 FUTURE: FACE CAPTURE NAVIGATION
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FaceCapturePage(
            studentUid: uid, 
            studentName: _nameCtrl.text.trim()
          ),
        ),
      ); 
      */
    } on FirebaseAuthException catch (e) {
      String msg = "Registration failed";
      if (e.code == 'email-already-in-use') msg = "Email already registered";
      if (e.code == 'weak-password') msg = "Password too weak";
      if (e.code == 'invalid-email') msg = "Invalid email";
      _showSnack(msg);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
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
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

                      _nameField(),
                      _emailField(),
                      _admissionField(),
                      _departmentDropdown(),
                      _classDropdown(),
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
                                    color: Colors.white,
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
  // FIELDS
  // ======================================================

  Widget _nameField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: _nameCtrl,
        decoration: InputDecoration(
          labelText: "Full Name",
          prefixIcon: const Icon(Icons.person),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _emailField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: _emailCtrl,
        inputFormatters: _noSpaceFormatter,
        decoration: InputDecoration(
          labelText: "Email ID",
          prefixIcon: const Icon(Icons.email),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _admissionField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: _admissionCtrl,
        keyboardType: TextInputType.number,
        // ✅ DIGITS ONLY
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: "Admission Number",
          prefixIcon: const Icon(Icons.badge),
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
        inputFormatters: _noSpaceFormatter,
        decoration: InputDecoration(
          labelText: "Password",
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ======================================================
  // DROPDOWNS (IMPROVED)
  // ======================================================

  Widget _departmentDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('departments').orderBy('name').snapshots(),
        builder: (_, snapshot) {
          // ⚠️ Error Handling (Important)
          if (snapshot.hasError) {
            return const Text(
              "Error loading departments. Check Permissions.",
              style: TextStyle(color: Colors.red),
            );
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Text("No Departments Found");

          return DropdownButtonFormField<String>(
            value: selectedDepartmentId,
            hint: const Text("Department"),
            items: docs.map((doc) {
              return DropdownMenuItem<String>(
                value: doc.id,
                child: Text(doc['name']),
              );
            }).toList(),
            onChanged: (val) {
              setState(() {
                selectedDepartmentId = val;
                selectedClassId = null;
              });
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

  Widget _classDropdown() {
    if (selectedDepartmentId == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('classes')
            .where('departmentId', isEqualTo: selectedDepartmentId)
            .snapshots(),
        builder: (_, snapshot) {
          // ⚠️ Error Handling
          if (snapshot.hasError) {
            return const Text(
              "Error loading classes.",
              style: TextStyle(color: Colors.red),
            );
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return const Text("No Classes in this Department");

          return DropdownButtonFormField<String>(
            value: selectedClassId,
            hint: const Text("Class"),
            items: docs.map((doc) {
              return DropdownMenuItem<String>(
                value: doc.id,
                child: Text(doc['name']),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => selectedClassId = val);
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.class_),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        },
      ),
    );
  }

  // ======================================================
  // SNACKBAR
  // ======================================================
  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

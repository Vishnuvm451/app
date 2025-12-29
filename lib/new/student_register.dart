import 'package:darzo/face_capture.dart';
import 'package:darzo/login.dart';
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

  final List<TextInputFormatter> _noSpaceFormatter = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
  ];

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
  // REGISTER STUDENT (FACE CAPTURE MANDATORY)
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

      // ---------- DUPLICATE ADMISSION CHECK ----------
      final existing = await _db
          .collection('students')
          .where('admissionNo', isEqualTo: _admissionCtrl.text.trim())
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        _showSnack("Admission number already exists");
        setState(() => isLoading = false);
        return;
      }

      // ---------- AUTH ----------
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // ---------- USERS ----------
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': _emailCtrl.text.trim(),
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // ---------- STUDENTS ----------
      await _db.collection('students').doc(uid).set({
        'uid': uid,
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'admissionNo': _admissionCtrl.text.trim(),
        'departmentId': selectedDepartmentId,
        'classId': selectedClassId,
        'face_enabled': false, // 🔒 REQUIRED
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // ---------- FACE CAPTURE (MANDATORY) ----------
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FaceCapturePage(
            studentUid: uid,
            studentName: _nameCtrl.text.trim(),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Registration failed";
      if (e.code == 'email-already-in-use') msg = "Email already registered";
      if (e.code == 'weak-password') msg = "Password too weak";
      if (e.code == 'invalid-email') msg = "Invalid email";
      _showSnack(msg);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Text(
                "DARZO",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 30),

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
                                "REGISTER & CAPTURE FACE",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ---------- LOGIN ----------
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
    );
  }

  // ======================================================
  // FIELDS
  // ======================================================
  Widget _nameField() =>
      _field(ctrl: _nameCtrl, label: "Full Name", icon: Icons.person);

  Widget _emailField() => _field(
    ctrl: _emailCtrl,
    label: "Email",
    icon: Icons.email,
    formatters: _noSpaceFormatter,
  );

  Widget _admissionField() => _field(
    ctrl: _admissionCtrl,
    label: "Admission Number",
    icon: Icons.badge,
    keyboard: TextInputType.number,
    formatters: [FilteringTextInputFormatter.digitsOnly],
  );

  Widget _passwordField() => _field(
    ctrl: _passwordCtrl,
    label: "Password",
    icon: Icons.lock,
    obscure: !showPassword,
    formatters: _noSpaceFormatter,
    suffix: IconButton(
      icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
      onPressed: () => setState(() => showPassword = !showPassword),
    ),
  );

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _departmentDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('departments').orderBy('name').snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();

          return DropdownButtonFormField<String>(
            value: selectedDepartmentId,
            hint: const Text("Department"),
            items: snap.data!.docs
                .map(
                  (d) => DropdownMenuItem(value: d.id, child: Text(d['name'])),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                selectedDepartmentId = v;
                selectedClassId = null;
              });
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.account_balance),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
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
        builder: (_, snap) {
          if (!snap.hasData) return const LinearProgressIndicator();

          return DropdownButtonFormField<String>(
            value: selectedClassId,
            hint: const Text("Class"),
            items: snap.data!.docs
                .map(
                  (d) => DropdownMenuItem(value: d.id, child: Text(d['name'])),
                )
                .toList(),
            onChanged: (v) => setState(() => selectedClassId = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.class_),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
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

import 'package:darzo/login.dart';
// import 'package:darzo/face_capture.dart';
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
  // REGISTER STUDENT
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

    setState(() => isLoading = true);

    try {
      // ---------------- CLASS VALIDATION ----------------
      final classSnap = await _db
          .collection('classes')
          .doc(selectedClassId)
          .get();

      if (!classSnap.exists) {
        _showSnack("Selected class does not exist");
        return;
      }

      final classData = classSnap.data()!;

      // ---------------- ADMISSION UNIQUE ----------------
      final existing = await _db
          .collection('students')
          .where('admissionNo', isEqualTo: _admissionCtrl.text.trim())
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        _showSnack("Admission number already exists");
        return;
      }

      // ---------------- AUTH ----------------
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // ---------------- USERS ----------------
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'email': _emailCtrl.text.trim(),
        'role': 'student',
        'created_at': FieldValue.serverTimestamp(),
      });

      // ---------------- STUDENTS ----------------
      await _db.collection('students').doc(uid).set({
        'uid': uid,
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'admissionNo': _admissionCtrl.text.trim(),
        'departmentId': selectedDepartmentId,
        'classId': selectedClassId,
        'courseType': classData['courseType'],
        'year': classData['year'],
        'face_enabled': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      _showSnack("Registration successful", success: true);

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Registration failed";
      if (e.code == 'email-already-in-use') msg = "Email already registered";
      if (e.code == 'weak-password') msg = "Weak password";
      if (e.code == 'invalid-email') msg = "Invalid email";
      _showSnack(msg);
    } catch (e) {
      _showSnack("Something went wrong");
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
  Widget _nameField() =>
      _field(controller: _nameCtrl, label: "Full Name", icon: Icons.person);

  Widget _emailField() => _field(
    controller: _emailCtrl,
    label: "Email ID",
    icon: Icons.email,
    formatters: _noSpaceFormatter,
  );

  Widget _admissionField() => _field(
    controller: _admissionCtrl,
    label: "Admission Number",
    icon: Icons.badge,
    keyboardType: TextInputType.number,
    formatters: [FilteringTextInputFormatter.digitsOnly],
  );

  Widget _passwordField() => Padding(
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    List<TextInputFormatter>? formatters,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        inputFormatters: formatters,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ======================================================
  // DROPDOWNS
  // ======================================================
  Widget _departmentDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('departments').orderBy('name').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: selectedDepartmentId,
          hint: const Text("Department"),
          items: snap.data!.docs
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d['name'])))
              .toList(),
          onChanged: (v) => setState(
            () => {selectedDepartmentId = v, selectedClassId = null},
          ),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.account_balance),
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }

  Widget _classDropdown() {
    if (selectedDepartmentId == null) return const SizedBox();
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('classes')
          .where('departmentId', isEqualTo: selectedDepartmentId)
          .orderBy('year')
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return const LinearProgressIndicator();
        return DropdownButtonFormField<String>(
          value: selectedClassId,
          hint: const Text("Class"),
          items: snap.data!.docs
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c['name'])))
              .toList(),
          onChanged: (v) => setState(() => selectedClassId = v),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.class_),
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }

  // ======================================================
  // SNACK
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

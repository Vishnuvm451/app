import 'package:darzo/auth/login.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:darzo/student/face_liveness_page.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _admissionCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String? selectedDepartmentId;
  String? selectedClassId;
  bool isLoading = false;
  bool showPassword = false;

  final Color primaryBlue = const Color(0xFF2196F3);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<TextInputFormatter> _noSpaceFormatter = [
    FilteringTextInputFormatter.deny(RegExp(r'\s')),
  ];

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

    final String admissionNo = _admissionCtrl.text.trim();
    UserCredential? cred;

    try {
      // 1. ✅ CREATE AUTH USER FIRST (So we are "Signed In")
      cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final user = cred.user;
      final String authUid = user!.uid;

      // ---------------------------------------------------------
      // 🆕 SEND VERIFICATION EMAIL (FORMALITY ONLY)
      // We catch errors so it doesn't stop the registration flow.
      // ---------------------------------------------------------
      user.sendEmailVerification().catchError((e) {
        print("Email verification failed to send: $e");
      });

      // 2. ✅ WRITE TO FIRESTORE
      // If admissionNo already exists, the Security Rules will REJECT this write
      final batch = _db.batch();

      final userRef = _db.collection('users').doc(authUid);
      batch.set(userRef, {
        'uid': authUid,
        'email': _emailCtrl.text.trim(),
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });

      final studentRef = _db.collection('student').doc(admissionNo);
      batch.set(studentRef, {
        'admissionNo': admissionNo,
        'authUid': authUid,
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'departmentId': selectedDepartmentId,
        'classId': selectedClassId,
        'face_enabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User added – Please enable face setup"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // ✅ Continue directly to Face Liveness (No Logout)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => FaceLivenessPage(
            admissionNo: admissionNo,
            studentName: _nameCtrl.text.trim(),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Registration failed");
    } on FirebaseException catch (e) {
      // 🔥 ROLLBACK: If Firestore fails (e.g. Admission Number taken), delete the Auth user
      if (cred?.user != null) {
        await cred!.user!.delete();
      }

      if (e.code == 'permission-denied') {
        _showSnack("Admission Number already exists or Permission Denied");
      } else {
        _showSnack("Database Error: ${e.message}");
      }
    } catch (e) {
      // General rollback
      if (cred?.user != null) await cred!.user!.delete();
      _showSnack("Something went wrong");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================= UI (UNCHANGED) =================

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
                    _field(_nameCtrl, "Full Name", Icons.person),
                    _field(
                      _emailCtrl,
                      "Email",
                      Icons.email,
                      formatters: _noSpaceFormatter,
                    ),
                    _field(
                      _admissionCtrl,
                      "Admission Number",
                      Icons.badge,
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    _departmentDropdown(),
                    _classDropdown(),
                    _field(
                      _passwordCtrl,
                      "Password",
                      Icons.lock,
                      obscure: !showPassword,
                      formatters: _noSpaceFormatter,
                      suffix: IconButton(
                        icon: Icon(
                          showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setState(() => showPassword = !showPassword),
                      ),
                    ),
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

  // ================= HELPERS =================

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
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
        stream: _db.collection('department').orderBy('name').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const LinearProgressIndicator();
          }
          return DropdownButtonFormField<String>(
            value: selectedDepartmentId,
            hint: const Text("Select Department"),
            decoration: InputDecoration(
              labelText: "Department",
              prefixIcon: const Icon(Icons.account_balance),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: snap.data!.docs
                .map(
                  (d) => DropdownMenuItem<String>(
                    value: d.id,
                    child: Text(d['name']),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() {
                selectedDepartmentId = v;
                selectedClassId = null;
              });
            },
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
            .collection('class')
            .where('departmentId', isEqualTo: selectedDepartmentId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const LinearProgressIndicator();
          }
          return DropdownButtonFormField<String>(
            value: selectedClassId,
            hint: const Text("Select Class"),
            decoration: InputDecoration(
              labelText: "Class",
              prefixIcon: const Icon(Icons.class_),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: snap.data!.docs
                .map(
                  (d) => DropdownMenuItem<String>(
                    value: d.id,
                    child: Text(d['name']),
                  ),
                )
                .toList(),
            onChanged: (v) {
              setState(() => selectedClassId = v);
            },
          );
        },
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

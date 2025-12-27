import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'login.dart'; // adjust path if needed

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  // ---------------- CONTROLLERS ----------------
  final _nameCtrl = TextEditingController();
  final _admissionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // ---------------- STATE ----------------
  String? selectedDepartmentId;
  String? selectedClassId;

  // ---------------- FIREBASE ----------------
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ======================================================
  // REGISTER STUDENT
  // ======================================================
  Future<void> registerStudent() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _admissionCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty ||
        selectedDepartmentId == null ||
        selectedClassId == null) {
      _showSnack("Fill all fields");
      return;
    }

    try {
      // 1️⃣ Firebase Auth
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final uid = cred.user!.uid;

      // 2️⃣ Fetch class details
      final classSnap = await _db
          .collection('classes')
          .doc(selectedClassId)
          .get();
      final classData = classSnap.data()!;

      // 3️⃣ Store student profile
      await _db.collection('students').doc(uid).set({
        'uid': uid,
        'name': _nameCtrl.text.trim(),
        'admissionNo': _admissionCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'departmentId': selectedDepartmentId,
        'classId': selectedClassId,
        'courseType': classData['courseType'],
        'year': classData['year'],
        'role': 'student',
        'created_at': FieldValue.serverTimestamp(),
      });

      _showSnack("Student registered successfully", success: true);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginPage()),
            );
          },
        ),
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 28),
            const SizedBox(width: 10),
            const Text("Darzo"),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_nameCtrl, "Full Name"),

          _field(_admissionCtrl, "Admission Number", denySpaces: true),

          _field(_emailCtrl, "Email", denySpaces: true),

          _field(_passwordCtrl, "Password", obscure: true, denySpaces: true),

          _departmentDropdown(),
          _classDropdown(),

          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: registerStudent,
            child: const Text("Register"),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // DROPDOWNS
  // ======================================================
  Widget _departmentDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('departments').snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return DropdownButtonFormField<String>(
          hint: const Text("Select Department"),
          value: selectedDepartmentId,
          items: snapshot.data!.docs
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d['name'])))
              .toList(),
          onChanged: (val) {
            setState(() {
              selectedDepartmentId = val;
              selectedClassId = null;
            });
          },
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
          .snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return DropdownButtonFormField<String>(
          hint: const Text("Select Class"),
          value: selectedClassId,
          items: snapshot.data!.docs
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c['name'])))
              .toList(),
          onChanged: (val) => setState(() => selectedClassId = val),
        );
      },
    );
  }

  // ======================================================
  // HELPERS
  // ======================================================
  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    bool denySpaces = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        inputFormatters: denySpaces
            ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))]
            : [],
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
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

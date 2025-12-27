import 'package:darzo/login.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

// import 'face_capture.dart'; // <--- UNCOMMENT THIS IN FUTURE

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  final _nameCtrl = TextEditingController();
  final _admissionCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String? selectedDepartmentId;
  String? selectedClassId;
  bool isLoading = false;
  bool showPassword = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _admissionCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> registerStudent() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _admissionCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty ||
        selectedDepartmentId == null ||
        selectedClassId == null) {
      _showSnack("Fill all fields");
      return;
    }

    if (_passwordCtrl.text.length < 6) {
      _showSnack("Password must be at least 6 characters");
      return;
    }

    setState(() => isLoading = true);

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );

      final uid = cred.user!.uid;

      final classSnap = await _db
          .collection('classes')
          .doc(selectedClassId)
          .get();

      if (!classSnap.exists) {
        if (mounted) _showSnack("Class not found");
        setState(() => isLoading = false);
        return;
      }

      final classData = classSnap.data()!;

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
        'face_enabled': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      await _db.collection('users').doc(uid).set({
        'role': 'student',
        'email': _emailCtrl.text.trim(),
      });

      if (mounted) {
        _showSnack("Registration successful!", success: true);
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        });
      }
    } catch (e) {
      if (mounted) _showSnack("Registration failed");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isLoading
              ? null
              : () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
        ),
        title: const Text("Darzo"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_nameCtrl, "Full Name"),
          _admissionField(),
          _field(_emailCtrl, "Email"),
          _passwordFieldWithToggle(),
          _departmentDropdown(),
          _classDropdown(),
          const SizedBox(height: 20),

          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : registerStudent,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      "Register",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),

          // 🔽 NEW ADDITION STARTS HERE 🔽
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
                          MaterialPageRoute(builder: (_) => LoginPage()),
                        );
                      },
                child: const Text(
                  "Login",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          // 🔼 NEW ADDITION ENDS HERE 🔼
        ],
      ),
    );
  }

  Widget _departmentDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('departments').snapshots(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 50);

          return DropdownButtonFormField<String>(
            hint: const Text("Select Department"),
            value: selectedDepartmentId,
            items: snapshot.data!.docs
                .map(
                  (d) => DropdownMenuItem(value: d.id, child: Text(d['name'])),
                )
                .toList(),
            onChanged: isLoading
                ? null
                : (val) {
                    setState(() {
                      selectedDepartmentId = val;
                      selectedClassId = null;
                    });
                  },
            decoration: const InputDecoration(border: OutlineInputBorder()),
          );
        },
      ),
    );
  }

  Widget _classDropdown() {
    if (selectedDepartmentId == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('classes')
            .where('departmentId', isEqualTo: selectedDepartmentId)
            .snapshots(),
        builder: (_, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 50);

          return DropdownButtonFormField<String>(
            hint: const Text("Select Class"),
            value: selectedClassId,
            items: snapshot.data!.docs
                .map(
                  (c) => DropdownMenuItem(value: c.id, child: Text(c['name'])),
                )
                .toList(),
            onChanged: isLoading
                ? null
                : (val) => setState(() => selectedClassId = val),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: !isLoading,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _admissionField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _admissionCtrl,
        enabled: !isLoading,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: "Admission Number",
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _passwordFieldWithToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _passwordCtrl,
        enabled: !isLoading,
        obscureText: !showPassword,
        decoration: InputDecoration(
          labelText: "Password",
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
            onPressed: isLoading
                ? null
                : () => setState(() => showPassword = !showPassword),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

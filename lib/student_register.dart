import 'package:darzo/login.dart';
import 'package:darzo/new/auth_service.dart';
import 'package:darzo/new/firestore_service.dart';
import 'package:flutter/material.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _admissionCtrl = TextEditingController();

  String? departmentId;
  String? classId;
  String? courseType;

  bool isLoading = false;

  // --------------------------------------------------
  // REGISTER STUDENT (FINAL LOGIC)
  // --------------------------------------------------
  Future<void> _registerStudent() async {
    if (_nameCtrl.text.isEmpty ||
        _emailCtrl.text.isEmpty ||
        _passwordCtrl.text.isEmpty ||
        _admissionCtrl.text.isEmpty ||
        departmentId == null ||
        classId == null ||
        courseType == null) {
      _showSnack("Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1️⃣ CREATE AUTH USER
      final user = await AuthService.instance.registerStudent(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      if (user == null) throw "Authentication failed";

      // 2️⃣ CREATE STUDENT PROFILE (FIRESTORE)
      await FirestoreService.instance.createStudentProfile(
        uid: user.uid,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        admissionNo: _admissionCtrl.text.trim(),
        departmentId: departmentId!,
        classId: classId!,
        courseType: courseType!,
      );

      if (!mounted) return;

      _showSnack("Student registered successfully", success: true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Student Registration")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_nameCtrl, "Full Name"),
          _field(_emailCtrl, "Email"),
          _field(_admissionCtrl, "Admission Number"),
          _field(_passwordCtrl, "Password", isPassword: true),

          const SizedBox(height: 12),

          // ---------------- DEPARTMENT ----------------
          FutureBuilder(
            future: FirestoreService.instance.getDepartments(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();

              return DropdownButtonFormField<String>(
                value: departmentId,
                hint: const Text("Select Department"),
                items: snapshot.data!
                    .map<DropdownMenuItem<String>>(
                      (d) => DropdownMenuItem(
                        value: d['id'],
                        child: Text(d['name']),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    departmentId = val;
                    classId = null;
                  });
                },
              );
            },
          ),

          const SizedBox(height: 12),

          // ---------------- CLASS ----------------
          if (departmentId != null)
            FutureBuilder(
              future: FirestoreService.instance.getClassesByDepartment(
                departmentId!,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                return DropdownButtonFormField<String>(
                  value: classId,
                  hint: const Text("Select Class"),
                  items: snapshot.data!
                      .map<DropdownMenuItem<String>>(
                        (c) => DropdownMenuItem(
                          value: c['id'],
                          child: Text(c['name']),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    final cls = snapshot.data!.firstWhere(
                      (c) => c['id'] == val,
                    );

                    setState(() {
                      classId = val;
                      courseType = cls['courseType'];
                    });
                  },
                );
              },
            ),

          const SizedBox(height: 24),

          // ---------------- REGISTER BUTTON ----------------
          ElevatedButton(
            onPressed: isLoading ? null : _registerStudent,
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("REGISTER"),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool isPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

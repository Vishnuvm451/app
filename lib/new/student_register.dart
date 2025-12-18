import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login.dart';

class StudentRegisterPage extends StatefulWidget {
  const StudentRegisterPage({super.key});

  @override
  State<StudentRegisterPage> createState() => _StudentRegisterPageState();
}

class _StudentRegisterPageState extends State<StudentRegisterPage> {
  // ---------------------------------------------------
  // CONTROLLERS
  // ---------------------------------------------------
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _admissionCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // ---------------------------------------------------
  // SELECTION STATE
  // ---------------------------------------------------
  String? departmentId;
  String? classId;
  String? courseType; // UG / PG
  int? year;

  bool isLoading = false;

  final List<String> courseTypes = ['UG', 'PG'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _admissionCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------
  // REGISTER STUDENT
  // ---------------------------------------------------
  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _admissionCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.trim().isEmpty ||
        departmentId == null ||
        classId == null ||
        courseType == null ||
        year == null) {
      _showSnack("Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      await AuthService.instance.registerStudent(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        admissionNo: _admissionCtrl.text.trim(),
        departmentId: departmentId!,
        classId: classId!,
        courseType: courseType!,
      );

      if (!mounted) return;

      _showSnack("Student registered successfully", success: true);

      await Future.delayed(const Duration(seconds: 1));

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

  // ---------------------------------------------------
  // BUILD
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2196F3);

    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'DARZO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
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
                      "STUDENT REGISTRATION",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _field(_nameCtrl, "Full Name", Icons.person),
                    _field(_admissionCtrl, "Admission Number", Icons.badge),
                    _field(_emailCtrl, "Email", Icons.email),
                    _field(
                      _passwordCtrl,
                      "Password",
                      Icons.lock,
                      obscure: true,
                    ),

                    const SizedBox(height: 14),

                    // ---------------- DEPARTMENT ----------------
                    FutureBuilder(
                      future: FirestoreService.instance.getDepartments(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }

                        final depts = snapshot.data!;

                        return DropdownButtonFormField<String>(
                          value: departmentId,
                          decoration: const InputDecoration(
                            labelText: "Department",
                            prefixIcon: Icon(Icons.account_balance),
                          ),
                          items: depts.map((d) {
                            return DropdownMenuItem(
                              value: d['id'],
                              child: Text(d['name']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              departmentId = val;
                              classId = null;
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // ---------------- COURSE TYPE ----------------
                    DropdownButtonFormField<String>(
                      value: courseType,
                      decoration: const InputDecoration(
                        labelText: "Course Type",
                        prefixIcon: Icon(Icons.school),
                      ),
                      items: courseTypes
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          courseType = val;
                          year = null;
                          classId = null;
                        });
                      },
                    ),

                    const SizedBox(height: 14),

                    // ---------------- YEAR ----------------
                    if (courseType != null)
                      DropdownButtonFormField<int>(
                        value: year,
                        decoration: const InputDecoration(
                          labelText: "Year",
                          prefixIcon: Icon(Icons.timeline),
                        ),
                        items: List.generate(
                          courseType == 'UG' ? 3 : 2,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text("Year ${i + 1}"),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            year = val;
                            classId = null;
                          });
                        },
                      ),

                    const SizedBox(height: 14),

                    // ---------------- CLASS ----------------
                    if (departmentId != null &&
                        courseType != null &&
                        year != null)
                      FutureBuilder(
                        future: FirestoreService.instance.getClasses(
                          departmentId: departmentId!,
                          courseType: courseType!,
                          year: year!,
                        ),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const LinearProgressIndicator();
                          }

                          final classes = snapshot.data!;

                          if (classes.isEmpty) {
                            return const Text(
                              "No classes found. Contact admin.",
                              style: TextStyle(color: Colors.red),
                            );
                          }

                          return DropdownButtonFormField<String>(
                            value: classId,
                            decoration: const InputDecoration(
                              labelText: "Class",
                              prefixIcon: Icon(Icons.class_),
                            ),
                            items: classes.map((c) {
                              return DropdownMenuItem(
                                value: c['id'],
                                child: Text(c['name']),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => classId = val);
                            },
                          );
                        },
                      ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _register,
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "REGISTER",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: const Text("Already have an account? Login"),
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

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/login.dart';
import 'package:darzo/parents/child_admisision_no.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ParentRegisterPage extends StatefulWidget {
  const ParentRegisterPage({super.key});

  @override
  State<ParentRegisterPage> createState() => _ParentRegisterPageState();
}

class _ParentRegisterPageState extends State<ParentRegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;

  final Color primaryBlue = const Color(0xFF2196F3);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // ✅ FIX: Trim all inputs before validation
      final String email = _emailCtrl.text.trim().toLowerCase();
      final String password = _passCtrl.text.trim();
      final String name = _nameCtrl.text.trim();
      final String mobile = _mobileCtrl.text.trim();

      // ✅ FIX: Validate email format
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
        _showCleanSnackBar("Invalid email format", isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // ✅ FIX: Validate password length
      if (password.length < 6) {
        _showCleanSnackBar(
          "Password must be at least 6 characters",
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }
      final db = FirebaseFirestore.instance;

      // 1️⃣ Check email already used in parents collection
      final emailSnap = await db
          .collection('parents')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailSnap.docs.isNotEmpty) {
        _showCleanSnackBar(
          "Email already registered. Please login.",
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2️⃣ Check mobile already used
      final mobileSnap = await db
          .collection('parents')
          .where('mobile', isEqualTo: mobile)
          .limit(1)
          .get();

      if (mobileSnap.docs.isNotEmpty) {
        _showCleanSnackBar("Mobile number already registered.", isError: true);
        setState(() => _isLoading = false);
        return;
      }

      debugPrint("🔐 Creating auth user: $email");

      // 1. Create Auth User
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;

      debugPrint("✅ Auth user created: $uid");

      // 2. Save to 'users' collection (For Login/Role Routing)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'role': 'parent',
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ User document created");

      // 3. Save to 'parents' collection (Profile Details)
      // ✅ FIX: Add child_face_linked field (critical for logic)
      await FirebaseFirestore.instance.collection('parents').doc(uid).set({
        'uid': uid,
        'name': name,
        'mobile': mobile,
        'email': email,
        'role': 'parent',
        'createdAt': FieldValue.serverTimestamp(),
        'linked_student_id': null,
        'is_student_linked': false,
        'child_face_linked': false,
        'has_attempted_link': false,
      });

      debugPrint("✅ Parent profile created with child_face_linked=false");

      if (!mounted) return;

      _showCleanSnackBar(
        "Registration successful! Please link your child.",
        isError: false,
      );

      // 4. Navigate to the Admission Number Page
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ConnectChildPage()),
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = "Password is too weak. Use at least 6 characters.";
          break;
        case 'email-already-in-use':
          message = "Email already registered. Please login instead.";
          break;
        case 'invalid-email':
          message = "Invalid email address.";
          break;
        case 'operation-not-allowed':
          message = "Registration is currently disabled. Try again later.";
          break;
        case 'too-many-requests':
          message = "Too many registration attempts. Try again later.";
          break;
        default:
          message = "Registration failed: ${e.message}";
      }
      debugPrint("❌ Auth error: ${e.code} - ${e.message}");
      _showCleanSnackBar(message, isError: true);
    } on FirebaseException catch (e) {
      debugPrint("❌ Firestore error: ${e.code} - ${e.message}");
      _showCleanSnackBar("Database error: ${e.message}", isError: true);
    } catch (e) {
      debugPrint("❌ Unexpected error: $e");
      _showCleanSnackBar("Error: ${e.toString()}", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCleanSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Parent Registration",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.family_restroom, size: 70, color: Colors.white),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const Text(
                        "Register",
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2196F3),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTextField(
                        _nameCtrl,
                        "Full Name",
                        Icons.person,
                        validator: (v) =>
                            v!.isEmpty ? "Name is required" : null,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _mobileCtrl,
                        "Mobile Number",
                        Icons.phone,
                        type: TextInputType.phone,
                        validator: (v) {
                          if (v!.isEmpty) return "Mobile is required";
                          if (v.length != 10) return "Mobile must be 10 digits";
                          return null;
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _emailCtrl,
                        "Email Address",
                        Icons.email,
                        type: TextInputType.emailAddress,
                        validator: (v) {
                          if (v!.isEmpty) return "Email is required";
                          if (!v.contains('@')) return "Invalid email";
                          return null;
                        },
                        inputFormatters: [
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 3,
                          ),
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "SUBMIT",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account? ",
                            style: TextStyle(fontSize: 15),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
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
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool isPass = false,
    TextInputType? type,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: isPass,
      keyboardType: type,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: primaryBlue),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passCtrl,
      obscureText: !_showPassword,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: "Password",
        labelStyle: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(Icons.lock, color: primaryBlue),
        suffixIcon: IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility : Icons.visibility_off,
            color: primaryBlue,
          ),
          onPressed: () => setState(() => _showPassword = !_showPassword),
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
      validator: (v) {
        if (v!.isEmpty) return "Password is required";
        if (v.length < 6) return "Password must be at least 6 characters";
        return null;
      },
    );
  }
}

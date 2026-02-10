import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/admin/admin_login.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:darzo/parents/child_admisision_no.dart';
import 'package:darzo/parents/child_face_scan.dart';
import 'package:darzo/parents/parent_dashboard.dart';
import 'package:darzo/auth/register_role_check.dart';
import 'package:darzo/student/face_liveness_page.dart';
import 'package:darzo/student/student_dashboard.dart';
import 'package:darzo/teacher/teacher_dashboard.dart';
import 'package:darzo/teacher/teacher_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:darzo/auth/forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isStudent = true;
  bool showPassword = false;
  bool isLoading = false;

  final Color primaryBlue = const Color(0xFF2196F3);

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  // ======================================================
  // LOGIN
  // ======================================================
  Future<void> _login() async {
    // 1. Basic Validation
    if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.isEmpty) {
      _showCleanSnackBar(
        "Please enter both email and password.",
        isError: true,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 2. AUTHENTICATION
      await context.read<AppAuthProvider>().login(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "Login failed. Please try again.";

      final uid = user.uid;
      debugPrint("🔐 Logged in user UID: $uid");
      debugPrint("📧 Email: ${emailCtrl.text.trim()}");

      // ======================================================
      // 3. CHECK USER PROFILE (Common 'users' collection)
      // ======================================================
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      debugPrint("📋 User Doc exists: ${userDoc.exists}");
      if (userDoc.exists) {
        debugPrint("📋 User Doc data: ${userDoc.data()}");
      }

      // 🚨 ACCOUNT PENDING / NOT REGISTERED
      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        throw "Your account is pending approval from Admin. Please wait.";
      }

      // ✅ FIXED: Better role extraction with proper string handling
      var roleValue = userDoc.data()?['role'];

      debugPrint("🔍 Raw role value: '$roleValue'");
      debugPrint("🔍 Role type: ${roleValue.runtimeType}");

      String role = '';
      if (roleValue != null) {
        role = roleValue
            .toString()
            .replaceAll(RegExp(r'\s+'), '') // Remove ALL whitespace
            .trim()
            .toLowerCase();
      }

      debugPrint("🔍 Processed role: '$role'");

      if (role.isEmpty) {
        // 🔁 FALLBACK ROLE DETECTION (FINAL SAFETY NET)

        final parentDoc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(uid)
            .get();

        if (parentDoc.exists) {
          role = 'parent';
          debugPrint("✅ Fallback: Found in parents collection");
        } else {
          final studentSnap = await FirebaseFirestore.instance
              .collection('student')
              .where('authUid', isEqualTo: uid)
              .limit(1)
              .get();

          if (studentSnap.docs.isNotEmpty) {
            role = 'student';
            debugPrint("✅ Fallback: Found in student collection");
          } else {
            final teacherDoc = await FirebaseFirestore.instance
                .collection('teacher')
                .doc(uid)
                .get();

            if (teacherDoc.exists) {
              role = 'teacher';
              debugPrint("✅ Fallback: Found in teacher collection");
            }
          }
        }
      }

      if (role.isEmpty) {
        await FirebaseAuth.instance.signOut();
        throw "User role not found in any collection. Please contact support.";
      }

      debugPrint("✅ Final role: '$role'");

      // ======================================================
      // 4. STUDENT FLOW
      // ======================================================
      if (role == 'student') {
        debugPrint("👤 Processing STUDENT login...");

        final studentQuery = await FirebaseFirestore.instance
            .collection('student')
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();

        debugPrint("📚 Student docs found: ${studentQuery.docs.length}");

        if (studentQuery.docs.isEmpty) {
          await FirebaseAuth.instance.signOut();
          throw "Student profile data is missing. Please contact admin.";
        }

        final studentDoc = studentQuery.docs.first;
        final admissionNo = studentDoc.id;
        final bool faceEnabled = studentDoc['face_enabled'] == true;

        debugPrint(
          "📚 Student admission: $admissionNo, Face enabled: $faceEnabled",
        );

        if (!mounted) return;

        if (!faceEnabled) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => FaceLivenessPage(
                admissionNo: admissionNo,
                studentName: studentDoc['name'] ?? 'Student',
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentDashboardPage()),
          );
        }
        return;
      }

      // ======================================================
      // 5. TEACHER FLOW
      // ======================================================
      if (role == 'teacher') {
        debugPrint("👨‍🏫 Processing TEACHER login...");

        final teacherDoc = await FirebaseFirestore.instance
            .collection('teacher')
            .doc(uid)
            .get();

        debugPrint("👨‍🏫 Teacher doc exists: ${teacherDoc.exists}");

        if (!teacherDoc.exists) {
          await FirebaseAuth.instance.signOut();
          throw "Teacher profile data is missing. Please contact admin.";
        }

        // Check if Teacher is Approved AND Setup is Done
        final bool isApproved = teacherDoc['isApproved'] == true;
        final bool setupCompleted = teacherDoc['setupCompleted'] == true;

        debugPrint(
          "👨‍🏫 Teacher approved: $isApproved, Setup completed: $setupCompleted",
        );

        if (!isApproved) {
          await FirebaseAuth.instance.signOut();
          throw "Your Teacher account is not approved yet. Please wait for admin approval.";
        }

        if (!mounted) return;

        if (!setupCompleted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeacherSetupPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
          );
        }
        return;
      }
      // ======================================================
      // 6. PARENT FLOW (✅ FIXED LOGIC)
      // ======================================================
      if (role == 'parent') {
        debugPrint("👨‍👩‍👧 Processing PARENT login...");

        final parentDoc = await FirebaseFirestore.instance
            .collection('parents')
            .doc(uid)
            .get();

        if (!parentDoc.exists) {
          await FirebaseAuth.instance.signOut();
          throw "Parent profile data is missing. Please register again.";
        }

        final data = parentDoc.data()!;

        final bool childFaceLinked = data['child_face_linked'] == true;
        final String? linkedStudentId =
            (data['linked_student_id'] != null &&
                data['linked_student_id'].toString().trim().isNotEmpty)
            ? data['linked_student_id'].toString().trim()
            : null;

        debugPrint("👨‍👩‍👧 linkedStudentId: $linkedStudentId");
        debugPrint("👨‍👩‍👧 childFaceLinked: $childFaceLinked");

        if (!mounted) return;

        if (linkedStudentId == null && childFaceLinked == true) {
          if (mounted) setState(() => isLoading = false);
          await FirebaseAuth.instance.signOut();
          throw "Parent account data is inconsistent. Please contact support.";
        }

        // 🔴 CASE 1: No child linked yet
        if (linkedStudentId == null && childFaceLinked == false) {
          debugPrint("➡️ Parent → ChildAdmissionNumberPage");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ConnectChildPage()),
          );
          return;
        }

        // 🟡 CASE 2: Child linked but face NOT verified
        if (linkedStudentId != null && childFaceLinked == false) {
          debugPrint("➡️ Parent → Child Face Scan Page");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ParentFaceScanPage(
                admissionNo: linkedStudentId,
                studentName: "Child",
              ),
            ),
          );
          return;
        }

        // 🟢 CASE 3: Child + face verified
        if (linkedStudentId != null && childFaceLinked == true) {
          debugPrint("➡️ Parent → ParentDashboard");
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ParentDashboard()),
          );
          return;
        }

        // 🚨 SAFETY NET (should never happen)
        await FirebaseAuth.instance.signOut();
        throw "Invalid parent account state. Please contact support.";
      }

      // ======================================================
      // 7. UNKNOWN ROLE
      // ======================================================
      debugPrint("❌ Unknown role detected: '$role'");
      await FirebaseAuth.instance.signOut();
      throw "Unknown user role: '$role'. Please contact support.";
    } on FirebaseAuthException catch (e) {
      // 🔥 SPECIFIC FIREBASE ERROR HANDLING
      String message;
      switch (e.code) {
        case 'invalid-credential':
        case 'user-not-found':
        case 'wrong-password':
          message = "Incorrect email or password.";
          break;
        case 'invalid-email':
          message = "The email format is invalid.";
          break;
        case 'user-disabled':
          message = "This account has been disabled.";
          break;
        case 'network-request-failed':
          message = "No internet connection.";
          break;
        case 'too-many-requests':
          message = "Too many attempts. Try again later.";
          break;
        default:
          message = "Login Error: ${e.message}";
      }
      debugPrint("🔥 Firebase Auth Error: ${e.code} - ${e.message}");
      _showCleanSnackBar(message, isError: true);
    } catch (e) {
      // 🔥 GENERIC ERROR HANDLING
      String cleanError = e.toString().replaceAll("Exception:", "").trim();
      debugPrint("❌ Login Error: $cleanError");
      debugPrint("❌ Error type: ${e.runtimeType}");
      debugPrint("❌ Full error: $e");
      _showCleanSnackBar(cleanError, isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ==========================================
  // ✨ CLEAN SNACKBAR HELPER
  // ==========================================
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
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  // ======================================================
  // UI (UNCHANGED - KEPT SAME)
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Stack(
            children: [
              Positioned(
                top: 5,
                right: 30,
                child: IconButton(
                  icon: const Icon(
                    Icons.admin_panel_settings,
                    color: Colors.white,
                    size: 55,
                  ),
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminLoginPage(),
                            ),
                          );
                        },
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 25),
                  const CircleAvatar(
                    radius: 37,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      Icons.access_time,
                      size: 37,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 17),
                  const Text(
                    "DARZO",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "LOGIN",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2196F3),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 13),
                        _inputField(
                          hint: "Email",
                          icon: Icons.email,
                          controller: emailCtrl,
                        ),
                        _passwordField(),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage(),
                                ),
                              );
                            },
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: Color(0xFF2196F3),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 3,
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text(
                                    "LOGIN",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 20,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(thickness: 1.5, color: Colors.grey),
                        const SizedBox(height: 10),
                        const Text(
                          "Don't have an account?",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _registerButton(
                          "REGISTER",
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterRoleCheck(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================================================
  // HELPERS (UNCHANGED)
  // ======================================================
  Widget _inputField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: primaryBlue),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.grey, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: passwordCtrl,
        obscureText: !showPassword,
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        decoration: InputDecoration(
          hintText: "Password",
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.lock, color: primaryBlue),
          suffixIcon: IconButton(
            icon: Icon(
              showPassword ? Icons.visibility : Icons.visibility_off,
              color: primaryBlue,
            ),
            onPressed: () => setState(() => showPassword = !showPassword),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.grey, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
          ),
        ),
      ),
    );
  }

  Widget _registerButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 2,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

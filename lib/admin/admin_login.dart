import 'package:darzo/admin/admin_dashboard.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for InputFormatters
import 'package:provider/provider.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;

  // Define the same blue used in your Login Page
  final Color primaryBlue = const Color(0xFF2196F3);

  // ✅ NEW: Cleaner snackbar with custom styling
  void _showSnack(String msg, {bool error = true}) {
    // Clear any existing snackbars
    ScaffoldMessenger.of(context).clearSnackBars();

    // ✅ FIX: Clean error message
    String cleanMsg = msg;
    if (msg.contains('firebase_auth')) {
      if (msg.contains('invalid-email')) {
        cleanMsg = 'Please enter a valid email address';
      } else if (msg.contains('user-not-found')) {
        cleanMsg = 'Email not found';
      } else if (msg.contains('wrong-password')) {
        cleanMsg = 'Incorrect password';
      } else if (msg.contains('too-many-requests')) {
        cleanMsg = 'Too many login attempts. Try again later';
      } else if (msg.contains('network-request-failed')) {
        cleanMsg = 'Network error. Check your connection';
      } else {
        cleanMsg = 'Authentication failed. Please try again';
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                cleanMsg,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: error ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: error ? 4 : 2),
        elevation: 8,
      ),
    );
  }

  Future<void> _loginAdmin() async {
    final auth = context.read<AppAuthProvider>();

    // ✅ NEW: Validate inputs
    if (_emailController.text.trim().isEmpty) {
      _showSnack("Please enter your email address");
      return;
    }

    if (_passwordController.text.trim().isEmpty) {
      _showSnack("Please enter your password");
      return;
    }

    try {
      await auth.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!auth.isLoggedIn) {
        _showSnack("Login failed. Please try again");
        return;
      }

      if (!auth.isAdmin) {
        await auth.logout();
        _showSnack("Access denied. Admin account required");
        return;
      }

      if (!mounted) return;

      // ✅ NEW: Success message before navigation
      _showSnack("Login successful", error: false);

      // Slight delay for success message to show
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
      );
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();

    return Scaffold(
      backgroundColor: primaryBlue,
      appBar: AppBar(
        title: const Text("Admin Login"),
        backgroundColor: primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ NEW: Better icon with container
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      size: 56,
                      color: primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "ADMIN LOGIN",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your admin credentials",
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 28),

                  // EMAIL
                  TextField(
                    controller: _emailController,
                    // ✅ BLOCK SPACES
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Admin Email",
                      hintText: "admin@school.com",
                      prefixIcon: const Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primaryBlue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // PASSWORD
                  TextField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    // ✅ BLOCK SPACES
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    decoration: InputDecoration(
                      labelText: "Password",
                      hintText: "Enter your password",
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primaryBlue, width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _loginAdmin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              "LOGIN",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'child_face_scan.dart';

class ConnectChildPage extends StatefulWidget {
  const ConnectChildPage({super.key});

  @override
  State<ConnectChildPage> createState() => _ConnectChildPageState();
}

class _ConnectChildPageState extends State<ConnectChildPage> {
  final _admissionCtrl = TextEditingController();
  bool _isLoading = false;

  final Color primaryBlue = const Color(0xFF2196F3);

  @override
  void dispose() {
    _admissionCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAdmission() async {
    // ✅ FIX: Input validation
    if (_admissionCtrl.text.isEmpty) {
      _showCleanSnackBar("Please enter admission number", isError: true);
      return;
    }

    final String admissionNum = _admissionCtrl.text.trim();

    // ✅ FIX: Validate admission number format (digits only)
    if (!RegExp(r'^\d+$').hasMatch(admissionNum)) {
      _showCleanSnackBar(
        "Admission number must contain only digits",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;

      // ✅ FIX: Check if user is logged in
      if (currentUser == null) {
        _showCleanSnackBar("Error: No user logged in!", isError: true);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      debugPrint(
        "🔍 Verifying admission: $admissionNum for user: ${currentUser.uid}",
      );

      // 1. Check if Student Exists in Firestore
      final studentDoc = await FirebaseFirestore.instance
          .collection('student')
          .doc(admissionNum)
          .get();

      debugPrint("📚 Student doc exists: ${studentDoc.exists}");

      if (!studentDoc.exists) {
        _showCleanSnackBar(
          "Admission Number not found in system!",
          isError: true,
        );
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final studentData = studentDoc.data() as Map<String, dynamic>;
      final String studentName = studentData['name'] ?? 'Student';

      debugPrint("✅ Student found: $studentName");

      // 2. Link student to parent immediately
      debugPrint("💾 Linking student to parent profile...");

      try {
        await FirebaseFirestore.instance
            .collection('parents')
            .doc(currentUser.uid)
            .update({
              'linked_student_id': admissionNum,
              'is_student_linked': true,
              'updated_at': FieldValue.serverTimestamp(),
            });

        debugPrint("✅ Parent profile updated with student link");
      } catch (e) {
        debugPrint("⚠️ Error updating parent profile: $e");
        _showCleanSnackBar(
          "Error linking student. Please try again.",
          isError: true,
        );
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;

      _showCleanSnackBar(
        "Student found! Proceeding to face scan...",
        isError: false,
      );

      // 3. Navigate to Face Scan Page after short delay
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ParentFaceScanPage(
            admissionNo: admissionNum,
            studentName: studentName,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint("❌ Firebase error: ${e.code} - ${e.message}");
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
          "Connect Child",
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Icon(
                  Icons.family_restroom,
                  size: 70,
                  color: Colors.white,
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        "Link Child",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2196F3),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Enter Student Admission Number",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _admissionCtrl,
                        enabled: !_isLoading,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: "e.g. 2024001",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: Icon(Icons.numbers, color: primaryBlue),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFF2196F3),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
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
                          onPressed: _isLoading ? null : _verifyAdmission,
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "Verify & Continue",
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
}

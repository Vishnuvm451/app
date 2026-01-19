import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:darzo/auth/login.dart';

class SettingsPage extends StatefulWidget {
  final String userRole; // 'student' or 'teacher'

  // These are now optional initial values
  final String? initialName;
  final String? initialSubTitle;

  const SettingsPage({
    super.key,
    required this.userRole,
    this.initialName,
    this.initialSubTitle,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isLoading = false;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Variables to hold profile data
  String displayName = "Loading...";
  String displaySubTitle = "";

  @override
  void initState() {
    super.initState();
    // 1. Set initial values if passed
    if (widget.initialName != null && widget.initialName != "Loading...") {
      displayName = widget.initialName!;
    }
    if (widget.initialSubTitle != null) {
      displaySubTitle = widget.initialSubTitle!;
    }

    // 2. Fetch fresh data from Firestore immediately
    _fetchProfileData();
  }

  // ==================================================
  // 0. FETCH PROFILE DATA (Self-Loading)
  // ==================================================
  Future<void> _fetchProfileData() async {
    if (currentUser == null) return;

    try {
      final collection = widget.userRole == 'student' ? 'student' : 'teacher';

      // Search by authUid first (safer)
      final query = await FirebaseFirestore.instance
          .collection(collection)
          .where('authUid', isEqualTo: currentUser!.uid)
          .limit(1)
          .get();

      DocumentSnapshot? doc;

      if (query.docs.isNotEmpty) {
        doc = query.docs.first;
      } else {
        // Fallback: Try document ID
        doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(currentUser!.uid)
            .get();
      }

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          displayName = data['name'] ?? "Unknown User";

          if (widget.userRole == 'student') {
            String adm = data['admissionNo'] ?? "N/A";
            displaySubTitle = "Adm No: $adm";
          } else {
            String dept = data['departmentId'] ?? "N/A";
            displaySubTitle = "Dept: $dept";
          }
        });
      }
    } catch (e) {
      print("Error fetching settings profile: $e");
    }
  }

  // ==================================================
  // 1. REMOVE FACE DATA (Student Only)
  // ==================================================
  Future<void> _removeFaceData() async {
    if (currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      // Logic: Update the document found via Query or ID
      final collection = 'student';
      // We assume the doc ID is the UID for simplicity in updates,
      // but strictly we should query if your doc IDs are admission numbers.
      // However, for this fix, we will try updating by UID first.

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(currentUser!.uid) // Trying Auth UID as Doc ID
          .update({
            'face_enabled': false,
            'face_registered_at': FieldValue.delete(),
          })
          .onError((e, _) async {
            // Fallback: If Doc ID != UID, find the doc by authUid and update it
            final q = await FirebaseFirestore.instance
                .collection(collection)
                .where('authUid', isEqualTo: currentUser!.uid)
                .get();

            if (q.docs.isNotEmpty) {
              await q.docs.first.reference.update({
                'face_enabled': false,
                'face_registered_at': FieldValue.delete(),
              });
            }
          });

      _showSnack("Face data removed successfully", Colors.green);
    } catch (e) {
      _showSnack("Failed to remove face data", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmRemoveFace() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Face Data?"),
        content: const Text(
          "You will not be able to mark attendance using your face until you re-register.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFaceData();
            },
            child: const Text("Remove", style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // 2. CHANGE PASSWORD
  // ==================================================
  Future<void> _changePassword(String oldPass, String newPass) async {
    if (currentUser == null) return;
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      String email = currentUser!.email!;
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: oldPass,
      );
      await currentUser!.reauthenticateWithCredential(credential);
      await currentUser!.updatePassword(newPass);
      _showSnack("Password changed successfully", Colors.green);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? "Password update failed", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showChangePasswordDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Change Password"),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldController,
                decoration: const InputDecoration(
                  labelText: "Current Password",
                ),
                obscureText: true,
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              TextFormField(
                controller: newController,
                decoration: const InputDecoration(labelText: "New Password"),
                obscureText: true,
                validator: (v) => v!.length < 6 ? "Min 6 chars" : null,
              ),
              TextFormField(
                controller: confirmController,
                decoration: const InputDecoration(
                  labelText: "Confirm Password",
                ),
                obscureText: true,
                validator: (v) =>
                    v != newController.text ? "Passwords do not match" : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                _changePassword(oldController.text, newController.text);
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // ==================================================
  // 3. DELETE ACCOUNT
  // ==================================================
  Future<void> _deleteAccount() async {
    if (currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      // 1. Delete Firestore Data (Try simple delete, handle fallback)
      String collection = widget.userRole == 'student' ? 'student' : 'teacher';

      await FirebaseFirestore.instance
          .collection(collection)
          .doc(currentUser!.uid)
          .delete()
          .onError((e, _) async {
            // Fallback for custom Doc IDs
            final q = await FirebaseFirestore.instance
                .collection(collection)
                .where('authUid', isEqualTo: currentUser!.uid)
                .get();
            for (var doc in q.docs) {
              await doc.reference.delete();
            }
          });

      // 2. Delete Auth
      await currentUser!.delete();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
      _showSnack("Account deleted permanently", Colors.grey);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnack(
          "Please log out and log in again to verify identity.",
          Colors.red,
        );
      } else {
        _showSnack("Error: ${e.message}", Colors.red);
      }
    } catch (e) {
      _showSnack("Delete failed", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account Permanent?"),
        content: const Text(
          "WARNING: This cannot be undone.\nAll your data will be erased immediately.",
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: const Text(
              "DELETE PERMANENTLY",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // ==================================================
  // UI BUILD
  // ==================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // PROFILE HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2196F3),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: Text(
                              "🧑‍🎓",
                              style: TextStyle(fontSize: 40),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          displayName, // ✅ Uses internal state
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          displaySubTitle, // ✅ Uses internal state
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentUser?.email ?? "No Email",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (widget.userRole == 'student') ...[
                    _sectionTitle("BIOMETRICS"),
                    _settingTile(
                      title: "Remove Face Data",
                      subtitle: "Delete registered face model",
                      icon: Icons.face_retouching_off,
                      iconColor: Colors.orange,
                      onTap: _confirmRemoveFace,
                    ),
                    const SizedBox(height: 16),
                  ],

                  _sectionTitle("ACCOUNT SECURITY"),
                  _settingTile(
                    title: "Change Password",
                    subtitle: "Update your login password",
                    icon: Icons.lock_reset,
                    iconColor: Colors.blue,
                    onTap: _showChangePasswordDialog,
                  ),
                  _settingTile(
                    title: "Delete Account",
                    subtitle: "Permanent removal",
                    icon: Icons.delete_forever,
                    iconColor: Colors.red,
                    onTap: _confirmDeleteAccount,
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    "Darzo v1.0.0",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _settingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}

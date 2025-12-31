import 'package:darzo/admin_approval.dart';
import 'package:darzo/admin_class_sub.dart';
import 'package:darzo/manage_department.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:darzo/admin_manage_users.dart';
import 'package:darzo/login.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  static const Color primaryBlue = Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 28),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          children: [
            _adminCard(
              icon: Icons.verified_user,
              title: "Teacher Approvals",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TeacherApprovalPage(),
                  ),
                );
              },
            ),
            _adminCard(
              icon: Icons.account_tree,
              title: "Departments & Classes",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAcademicSetupPage(),
                  ),
                );
              },
            ),
            _adminCard(
              icon: Icons.people,
              title: "Manage Users",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminManageUsersPage(),
                  ),
                );
              },
            ),

            _adminCard(
              icon: Icons.settings,
              title: "Manage Department",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminManageAcademicPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // ADMIN CARD
  // =====================================================
  Widget _adminCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: primaryBlue),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

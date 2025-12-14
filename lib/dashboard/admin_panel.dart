import 'package:flutter/material.dart';
import 'package:darzo/admin/add_student.dart';
import 'package:darzo/admin/teacher_approval_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2196F3),
      appBar: AppBar(
        elevation: 0,
        title: const Text("Admin Panel"),
        backgroundColor: Color(0xFF2196F3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _adminCard(
              Icons.people,
              "Manage Teachers",
              context,
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
              Icons.school,
              "Add Students",
              context,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddStudentPage()),
                );
              },
            ),

            _adminCard(Icons.class_, "Classes & Subjects", context),
            _adminCard(Icons.checklist, "Attendance Reports", context),
            _adminCard(Icons.bar_chart, "Marks Reports", context),
            _adminCard(Icons.settings, "Settings", context),
          ],
        ),
      ),
    );
  }

  Widget _adminCard(
    IconData icon,
    String title,
    BuildContext context, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap:
          onTap ??
          () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("$title – coming soon")));
          },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.indigo),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

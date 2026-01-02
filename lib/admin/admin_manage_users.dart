import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminManageUsersPage extends StatefulWidget {
  const AdminManageUsersPage({super.key});

  @override
  State<AdminManageUsersPage> createState() => _AdminManageUsersPageState();
}

class _AdminManageUsersPageState extends State<AdminManageUsersPage> {
  final Color primaryBlue = const Color(0xFF2196F3);
  String searchQuery = "";

  // ======================================================
  // CONFIRM DELETE DIALOG
  // ======================================================
  Future<bool> _confirmDelete(BuildContext context, String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Confirm Delete"),
            content: Text("Are you sure you want to delete $name?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ======================================================
  // DELETE STUDENT (ADMISSION BASED)
  // ======================================================
  Future<void> _deleteStudent(String admissionNo, String name) async {
    final confirmed = await _confirmDelete(context, name);
    if (!confirmed) return;

    final studentRef = FirebaseFirestore.instance
        .collection('student')
        .doc(admissionNo);
    final snap = await studentRef.get();

    if (!snap.exists) return;

    final data = snap.data() as Map<String, dynamic>;
    final authUid = data['authUid'];

    await studentRef.delete();
    await FirebaseFirestore.instance.collection('users').doc(authUid).delete();
  }

  // ======================================================
  // DELETE TEACHER
  // ======================================================
  Future<void> _deleteTeacher(String uid, String name) async {
    final confirmed = await _confirmDelete(context, name);
    if (!confirmed) return;

    await FirebaseFirestore.instance.collection('teacher').doc(uid).delete();
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
  }

  // ======================================================
  // UI
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Manage Users"),
        backgroundColor: primaryBlue,
      ),
      body: Column(
        children: [
          _searchBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionTitle("Students"),
                _studentsList(),
                const SizedBox(height: 30),
                _sectionTitle("Teachers"),
                _teachersList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // SEARCH BAR
  // ======================================================
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search by name or email",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onChanged: (v) => setState(() => searchQuery = v.toLowerCase()),
      ),
    );
  }

  // ======================================================
  // STUDENTS LIST
  // ======================================================
  Widget _studentsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('student').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final students = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();

          return name.contains(searchQuery) || email.contains(searchQuery);
        });

        return Column(children: students.map(_studentCard).toList());
      },
    );
  }

  Widget _studentCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'Email not available';
    final departmentId = data['departmentId'] ?? '-';
    final classId = data['classId'] ?? '-';
    final faceEnabled = data['face_enabled'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(email),
            Text("Admission: ${doc.id}"),
            Text("Department: $departmentId"),
            Text("Class: $classId"),
            Text(
              "Face: ${faceEnabled ? 'Enabled' : 'Not Registered'}",
              style: TextStyle(color: faceEnabled ? Colors.green : Colors.red),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _actionButton("Edit", Icons.edit, () {}),
                const SizedBox(width: 10),
                _actionButton(
                  "Delete",
                  Icons.delete,
                  () => _deleteStudent(doc.id, name),
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // TEACHERS LIST
  // ======================================================
  Widget _teachersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('teacher').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final teachers = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();

          return name.contains(searchQuery) || email.contains(searchQuery);
        });

        return Column(children: teachers.map(_teacherCard).toList());
      },
    );
  }

  Widget _teacherCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'Email not available';
    final departmentId = data['departmentId'] ?? '-';
    final approved = data['isApproved'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(email),
            Text("Department: $departmentId"),
            Text(
              approved ? "Approved" : "Pending",
              style: TextStyle(color: approved ? Colors.green : Colors.orange),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _actionButton("Edit", Icons.edit, () {}),
                const SizedBox(width: 10),
                _actionButton(
                  "Delete",
                  Icons.delete,
                  () => _deleteTeacher(doc.id, name),
                  color: Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // COMMON UI
  // ======================================================
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.blue,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageAcademicPage extends StatefulWidget {
  const AdminManageAcademicPage({super.key});

  @override
  State<AdminManageAcademicPage> createState() =>
      _AdminManageAcademicPageState();
}

class _AdminManageAcademicPageState extends State<AdminManageAcademicPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------
  // 1. DELETE DEPARTMENT LOGIC
  // ---------------------------------------------------
  Future<void> _deleteDepartment(String docId, String name) async {
    // Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Department?"),
        content: Text(
          "Are you sure you want to delete '$name'?\n\n⚠️ This will NOT delete the associated classes/subjects automatically. You should delete them first.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _db.collection('department').doc(docId).delete();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Department Deleted")));
    }
  }

  // ---------------------------------------------------
  // 2. EDIT DEPARTMENT LOGIC
  // ---------------------------------------------------
  Future<void> _editDepartment(String docId, String currentName) async {
    final TextEditingController ctrl = TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Department Name"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: "New Name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await _db.collection('department').doc(docId).update({
                  'name': ctrl.text.trim(),
                });
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------
  // UI: DEPARTMENT LIST
  // ---------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Departments"),
        backgroundColor: const Color(0xFF2196F3),
      ),
      backgroundColor: Colors.grey.shade100,
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('department').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text("No Departments Found"));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final id = docs[index].id;
              final name = data['name'] ?? "Unknown";

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Text(
                      name[0],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(
                    "Click to view Classes & Subjects",
                    style: const TextStyle(fontSize: 10),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () => _editDepartment(id, name),
                      ),
                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteDepartment(id, name),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Navigate to Details Page (Classes & Subjects)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DepartmentDetailsPage(deptId: id, deptName: name),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// =======================================================
// DETAIL PAGE: SHOWS CLASSES & SUBJECTS
// =======================================================
class DepartmentDetailsPage extends StatelessWidget {
  final String deptId;
  final String deptName;

  const DepartmentDetailsPage({
    super.key,
    required this.deptId,
    required this.deptName,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(deptName),
          backgroundColor: const Color(0xFF2196F3),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Classes"),
              Tab(text: "Subjects"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ClassesList(deptId: deptId),
            _SubjectsList(deptId: deptId),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------
// TAB 1: CLASSES LIST
// ---------------------------------------------------
class _ClassesList extends StatelessWidget {
  final String deptId;
  const _ClassesList({required this.deptId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('class')
          .where('departmentId', isEqualTo: deptId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("No Classes found for this department."),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.class_, color: Colors.blueGrey),
                title: Text(data['name']),
                subtitle: Text("Year ${data['year']} • ${data['courseType']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteItem(context, 'classes', doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteItem(
    BuildContext context,
    String collection,
    String docId,
  ) async {
    // Simple delete confirmation
    await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Item Deleted")));
    }
  }
}

// ---------------------------------------------------
// TAB 2: SUBJECTS LIST
// ---------------------------------------------------
class _SubjectsList extends StatelessWidget {
  final String deptId;
  const _SubjectsList({required this.deptId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('subject')
          .where('departmentId', isEqualTo: deptId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("No Subjects found for this department."),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.book, color: Colors.teal),
                title: Text(data['name']),
                subtitle: Text("${data['semester']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => _deleteItem(context, 'subjects', doc.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteItem(
    BuildContext context,
    String collection,
    String docId,
  ) async {
    await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Subject Deleted")));
    }
  }
}

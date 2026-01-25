import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminManageHODPage extends StatefulWidget {
  const AdminManageHODPage({super.key});

  @override
  State<AdminManageHODPage> createState() => _AdminManageHODPageState();
}

class _AdminManageHODPageState extends State<AdminManageHODPage> {
  Map<String, String> departmentNames = {};
  bool isLoadingDepts = true;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  // 1. Fetch Department Names for Lookup
  Future<void> _fetchDepartments() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('department')
          .get();
      final Map<String, String> loadedDepts = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Try getting name from 'name' or 'deptName', fallback to Document ID
        String name = data['name'] ?? data['deptName'] ?? doc.id;

        // Map Document ID to Name
        loadedDepts[doc.id] = name;

        // If there is a specific 'deptId' field, map that too just in case
        if (data['deptId'] != null) {
          loadedDepts[data['deptId']] = name;
        }
      }

      if (mounted) {
        setState(() {
          departmentNames = loadedDepts;
          isLoadingDepts = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching departments: $e");
      if (mounted) setState(() => isLoadingDepts = false);
    }
  }

  // 2. Toggle HOD Status
  Future<void> _toggleHOD(
    String docId,
    bool currentStatus,
    String deptId,
  ) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final docRef = FirebaseFirestore.instance
          .collection('teacher')
          .doc(docId);

      // If assigning as HOD (currentStatus is false), remove old HODs
      if (!currentStatus) {
        final oldHODs = await FirebaseFirestore.instance
            .collection('teacher')
            .where('departmentId', isEqualTo: deptId)
            .where('isHOD', isEqualTo: true)
            .get();

        for (var doc in oldHODs.docs) {
          batch.update(doc.reference, {'isHOD': false});
        }
      }

      // Update target teacher
      batch.update(docRef, {'isHOD': !currentStatus});

      await batch.commit();

      if (mounted) {
        final isAssigned = !currentStatus;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAssigned ? "Assigned as HOD!" : "Removed as HOD",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            // ✅ Color Logic: Green for Add, Red for Remove
            backgroundColor: isAssigned ? Colors.green : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Assign HOD"),
        centerTitle: true,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('teacher').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || isLoadingDepts) {
            return const Center(child: CircularProgressIndicator());
          }

          final teachers = snapshot.data!.docs;

          if (teachers.isEmpty) {
            return const Center(child: Text("No teachers found"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final data = teachers[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'Unknown';
              final deptId = data['departmentId'] ?? '';
              final isHOD = data['isHOD'] ?? false;

              // ✅ Lookup Department Name from Map (Fallback to ID if not found)
              final deptName = departmentNames[deptId] ?? deptId;

              return Card(
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
                    backgroundColor: isHOD
                        ? Colors.orange
                        : Colors.blue.shade100,
                    child: Icon(
                      isHOD ? Icons.star : Icons.person,
                      color: isHOD ? Colors.white : Colors.blue,
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
                    "Dept: ${deptName.isNotEmpty ? deptName : 'No Department'}",
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  trailing: Switch(
                    value: isHOD,
                    activeColor: Colors.orange,
                    onChanged: (val) =>
                        _toggleHOD(teachers[index].id, isHOD, deptId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ViewTeachersPage extends StatefulWidget {
  const ViewTeachersPage({super.key});

  @override
  State<ViewTeachersPage> createState() => _ViewTeachersPageState();
}

class _ViewTeachersPageState extends State<ViewTeachersPage> {
  bool isLoading = true;
  String? myDeptId;
  List<Map<String, dynamic>> teachersList = [];

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Get Student Dept ID
      final studentDoc = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (studentDoc.docs.isEmpty) return;

      // Assuming you store 'departmentId' in student doc (e.g. "COMPUTER_SCIENCE")
      myDeptId = studentDoc.docs.first.data()['departmentId'];

      if (myDeptId == null) return;

      // 2. Fetch Teachers for this Dept
      final teacherQuery = await FirebaseFirestore.instance
          .collection('teacher')
          .where('departmentId', isEqualTo: myDeptId)
          .get();

      final List<Map<String, dynamic>> loadedTeachers = teacherQuery.docs.map((
        doc,
      ) {
        final data = doc.data();
        data['id'] = doc.id; // Keep doc ID handy
        return data;
      }).toList();

      // 3. ✅ SORT: HOD goes to Index 0
      loadedTeachers.sort((a, b) {
        final isHOD_A = a['isHOD'] ?? false;
        final isHOD_B = b['isHOD'] ?? false;
        if (isHOD_A && !isHOD_B) return -1; // A comes first
        if (!isHOD_A && isHOD_B) return 1; // B comes first
        return 0;
      });

      if (mounted) {
        setState(() {
          teachersList = loadedTeachers;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading teachers: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Teachers"),
        centerTitle: true,
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : teachersList.isEmpty
          ? const Center(child: Text("No teachers found for your department."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: teachersList.length,
              itemBuilder: (context, index) {
                final teacher = teachersList[index];
                final isHOD = teacher['isHOD'] == true;
                final name = teacher['name'] ?? "Unknown";

                return Card(
                  elevation: isHOD ? 4 : 1,
                  shadowColor: isHOD ? Colors.orange.withOpacity(0.4) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isHOD
                        ? const BorderSide(color: Colors.orange, width: 2)
                        : BorderSide.none,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
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
                        isHOD ? Icons.star_rounded : Icons.person,
                        color: isHOD ? Colors.white : Colors.blue.shade700,
                        size: 28,
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isHOD ? Colors.orange.shade800 : Colors.black87,
                      ),
                    ),
                    subtitle: isHOD
                        ? const Text(
                            "Head of Department",
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : const Text("Faculty Member"),
                    trailing: isHOD
                        ? const Chip(
                            label: Text(
                              "HOD",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            backgroundColor: Colors.orange,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherStudentsListPage extends StatefulWidget {
  const TeacherStudentsListPage({super.key});

  @override
  State<TeacherStudentsListPage> createState() =>
      _TeacherStudentsListPageState();
}

class _TeacherStudentsListPageState extends State<TeacherStudentsListPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Color primaryBlue = const Color(0xFF2196F3);

  String? departmentId;
  String? selectedClassId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  // --------------------------------------------------
  // 1. LOAD TEACHER PROFILE
  // --------------------------------------------------
  Future<void> _loadTeacherProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await _db.collection('teacher').doc(user.uid).get();
      if (!snap.exists) return;

      final data = snap.data()!;

      if (mounted) {
        setState(() {
          departmentId = data['departmentId'];
          // We load it, but we validate it in the StreamBuilder later
          selectedClassId = data['classId'];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --------------------------------------------------
  // UI BUILD
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Students List",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _classDropdown(), // ✅ Fixed Dropdown
                Expanded(child: _studentsList()),
              ],
            ),
    );
  }

  // --------------------------------------------------
  // CLASS DROPDOWN (FIXED)
  // --------------------------------------------------
  Widget _classDropdown() {
    if (departmentId == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('class')
            .where('departmentId', isEqualTo: departmentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 50,
              child: Center(child: LinearProgressIndicator()),
            );
          }

          final classes = snapshot.data!.docs;

          // Client-side Sort
          classes.sort((a, b) {
            final yearA = (a.data() as Map)['year'] ?? 0;
            final yearB = (b.data() as Map)['year'] ?? 0;
            return yearA.compareTo(yearB);
          });

          // 🔴 CRITICAL FIX: Ensure selectedClassId actually exists in the list
          // If it's not in the list, set value to null to prevent crash
          final isValidSelection = classes.any(
            (doc) => doc.id == selectedClassId,
          );
          final dropdownValue = isValidSelection ? selectedClassId : null;

          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: dropdownValue, // ✅ Use safe value
              hint: const Text("Select Class"),
              isExpanded: true,
              icon: Icon(Icons.arrow_drop_down_circle, color: primaryBlue),
              items: classes.map((doc) {
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(
                    doc['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  selectedClassId = val;
                });
              },
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // STUDENTS LIST
  // --------------------------------------------------
  Widget _studentsList() {
    if (selectedClassId == null) {
      return Center(
        child: Text(
          "Please select a class",
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('student')
          .where('classId', isEqualTo: selectedClassId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.group_off_rounded,
                  size: 60,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 10),
                Text(
                  "No students found in this class",
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        final students = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final data = students[index].data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Unknown';
            final admissionNo = data['admissionNo'] ?? 'No ID';
            final email = data['email'] ?? '';
            final bool faceRegistered = data['face_enabled'] == true;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: primaryBlue.withOpacity(0.1),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "ID: $admissionNo",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Status Badge (Face Registered)
                    if (faceRegistered)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.face,
                          size: 20,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

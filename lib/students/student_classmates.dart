import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentViewClassmatesPage extends StatefulWidget {
  const StudentViewClassmatesPage({super.key});

  @override
  State<StudentViewClassmatesPage> createState() =>
      _StudentViewClassmatesPageState();
}

class _StudentViewClassmatesPageState extends State<StudentViewClassmatesPage> {
  // ---------------- STATE ----------------
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  late Future<Map<String, String>?> _myDetailsFuture;

  @override
  void initState() {
    super.initState();
    _myDetailsFuture = _fetchMyDetails();
  }

  // 1. Fetch Logged-in Student's Class & Dept
  Future<Map<String, String>?> _fetchMyDetails() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('students')
        .doc(uid)
        .get();

    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      return {
        'class_name': data['class_name'] ?? '',
        // ✅ FIX 1: Read 'department' (Name) instead of 'departmentId'
        // based on your screenshot showing "department": "Computer Science"
        'department': data['department'] ?? '',
        'myUid': uid,
      };
    }
    return null;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2196F3);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("My Classmates"),
        backgroundColor: primaryBlue,
        elevation: 0,
        // Add back button support manually if needed, or rely on default
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<Map<String, String>?>(
        future: _myDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            return _emptyState("Could not load your class details.");
          }

          final myClass = snapshot.data!['class_name']!;
          // ✅ FIX 2: Use the variable we fetched above
          final myDept = snapshot.data!['department']!;
          final myUid = snapshot.data!['myUid']!;

          if (myClass.isEmpty) {
            return _emptyState("You are not assigned to a class yet.");
          }

          return Column(
            children: [
              // ---------------- HEADER INFO ----------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: primaryBlue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Class: $myClass",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Optional: Show Department
                    Text(
                      "Dept: $myDept",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => searchQuery = val.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: "Search classmates...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ---------------- STUDENTS LIST ----------------
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('students')
                      .where('class_name', isEqualTo: myClass)
                      // ✅ FIX 3: Query by 'department' field
                      .where('department', isEqualTo: myDept)
                      .orderBy('name')
                      .snapshots(),
                  builder: (context, streamSnap) {
                    if (streamSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!streamSnap.hasData || streamSnap.data!.docs.isEmpty) {
                      return _emptyState("No classmates found.");
                    }

                    // Client-side search filtering
                    final students = streamSnap.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final regNo = (data['register_number'] ?? '')
                          .toString()
                          .toLowerCase(); // Check if your DB uses 'register_number' or 'admission_no'
                      final admissionNo = (data['admission_no'] ?? '')
                          .toString()
                          .toLowerCase(); // Covering both cases

                      return name.contains(searchQuery) ||
                          regNo.contains(searchQuery) ||
                          admissionNo.contains(searchQuery);
                    }).toList();

                    if (students.isEmpty) {
                      return _emptyState("No matching results.");
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final doc = students[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final bool isMe = doc.id == myUid;

                        // Check DB field name for display
                        final displayRegNo =
                            data['register_number'] ??
                            data['admission_no'] ??
                            'N/A';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isMe
                                ? const BorderSide(color: primaryBlue, width: 2)
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isMe
                                  ? primaryBlue
                                  : primaryBlue.withOpacity(0.1),
                              child: Text(
                                (data['name'] ?? "U")[0].toUpperCase(),
                                style: TextStyle(
                                  color: isMe ? Colors.white : primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    data['name'] ?? "Unknown",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMe) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                    child: const Text(
                                      "YOU",
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: primaryBlue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                "Reg No: $displayRegNo",
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

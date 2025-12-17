import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentStudentsListPage extends StatefulWidget {
  const StudentStudentsListPage({super.key});

  @override
  State<StudentStudentsListPage> createState() =>
      _StudentStudentsListPageState();
}

class _StudentStudentsListPageState extends State<StudentStudentsListPage> {
  // ---------------- STATE ----------------
  String? selectedClass; // For Dropdown Filter
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // We need to fetch the Teacher's Department ID first
  late Future<String?> _teacherDeptFuture;

  @override
  void initState() {
    super.initState();
    _teacherDeptFuture = _fetchTeacherDepartmentId();
  }

  // 1. Fetch Logged-in Teacher's Department ID
  Future<String?> _fetchTeacherDepartmentId() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(uid)
        .get();

    if (doc.exists && doc.data() != null) {
      return doc.data()!['departmentId'] as String?;
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
        title: const Text("My Students"),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      // Wait for Teacher Data (Department ID)
      body: FutureBuilder<String?>(
        future: _teacherDeptFuture,
        builder: (context, teacherSnap) {
          if (teacherSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (teacherSnap.hasError || !teacherSnap.hasData) {
            return _emptyState("Could not verify your department.");
          }

          final String teacherDeptId = teacherSnap.data!;

          return Column(
            children: [
              // ---------------- FILTERS SECTION ----------------
              Container(
                padding: const EdgeInsets.all(16),
                color: primaryBlue,
                child: Column(
                  children: [
                    // 1. CLASS DROPDOWN (Filtered by Dept)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        // Only fetch classes belonging to this Teacher's Department
                        stream: FirebaseFirestore.instance
                            .collection('classes')
                            .where('departmentId', isEqualTo: teacherDeptId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              height: 50,
                              child: Center(child: LinearProgressIndicator()),
                            );
                          }

                          // Get list of class names
                          List<String> classes = snapshot.data!.docs
                              .map((doc) => doc['name'] as String)
                              .toList();

                          // Sort alphabetically
                          classes.sort();

                          return DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedClass,
                              hint: const Text("Filter by Class (All)"),
                              isExpanded: true,
                              icon: const Icon(
                                Icons.filter_list,
                                color: primaryBlue,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text(
                                    "All Classes",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ...classes.map((className) {
                                  return DropdownMenuItem(
                                    value: className,
                                    child: Text(className),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  selectedClass = val;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. SEARCH BAR
                    TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          setState(() => searchQuery = val.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: "Search by Name or Reg No...",
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

              // ---------------- STUDENT LIST ----------------
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _getStudentStream(teacherDeptId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _emptyState(
                        "No students found in your department.",
                      );
                    }

                    // 🔍 Client-side filtering for Search Query
                    final students = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '')
                          .toString()
                          .toLowerCase();
                      final regNo = (data['register_number'] ?? '')
                          .toString()
                          .toLowerCase();

                      return name.contains(searchQuery) ||
                          regNo.contains(searchQuery);
                    }).toList();

                    if (students.isEmpty) {
                      return _emptyState("No matching results.");
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: students.length,
                      itemBuilder: (context, index) {
                        final data =
                            students[index].data() as Map<String, dynamic>;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: primaryBlue.withOpacity(0.1),
                              child: Text(
                                (data['name'] ?? "U")[0].toUpperCase(),
                                style: const TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              data['name'] ?? "Unknown",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.class_outlined,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      data['class_name'] ?? 'No Class',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Reg: ${data['register_number'] ?? 'N/A'}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              _showStudentDetails(context, data);
                            },
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

  // ---------------- LOGIC ----------------

  Stream<QuerySnapshot> _getStudentStream(String teacherDeptId) {
    CollectionReference studentsRef = FirebaseFirestore.instance.collection(
      'students',
    );

    // 1. BASE QUERY: Only show students from Teacher's Department
    Query query = studentsRef.where('departmentId', isEqualTo: teacherDeptId);

    // 2. FILTER: If a class is selected, filter by class name
    if (selectedClass != null && selectedClass!.isNotEmpty) {
      query = query.where('class_name', isEqualTo: selectedClass);
    }

    // 3. ORDER: Alphabetical
    return query.orderBy('name').snapshots();
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 60,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _showStudentDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Student Details",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 10),
              _detailRow("Name", data['name']),
              _detailRow("Register No", data['register_number']),
              // _detailRow("Email", data['email']), // 🔒 REMOVED FOR PRIVACY
              _detailRow("Class", data['class_name']),
              _detailRow("Semester", data['semester']),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value ?? "-",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

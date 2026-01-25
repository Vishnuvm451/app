import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminManageUsersPage extends StatefulWidget {
  const AdminManageUsersPage({super.key});

  @override
  State<AdminManageUsersPage> createState() => _AdminManageUsersPageState();
}

class _AdminManageUsersPageState extends State<AdminManageUsersPage> {
  final Color primaryBlue = const Color(0xFF2196F3);

  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  // 0 = Students, 1 = Teachers
  int _selectedView = 0;

  // CACHE FOR NAMES (ID -> Real Name)
  Map<String, String> _deptNames = {};
  Map<String, String> _classNames = {};

  @override
  void initState() {
    super.initState();
    _fetchMetadata();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ======================================================
  // 1. FETCH REAL NAMES (FIXED COLLECTIONS)
  // ======================================================
  Future<void> _fetchMetadata() async {
    try {
      // ✅ FIXED: Changed 'departments' to 'department' (Singular)
      final deptSnap = await FirebaseFirestore.instance
          .collection('department')
          .get();
      final Map<String, String> loadedDepts = {};

      for (var doc in deptSnap.docs) {
        final data = doc.data();
        // Use 'name' field (e.g., "Bcom", "Computer Science")
        String name = data['name'] ?? data['deptName'] ?? doc.id;
        loadedDepts[doc.id] = name;
      }
      print("✅ Loaded ${loadedDepts.length} Departments");

      // ✅ FIXED: Changed 'classes' to 'class' (Singular)
      final classSnap = await FirebaseFirestore.instance
          .collection('class')
          .get();
      final Map<String, String> loadedClasses = {};

      for (var doc in classSnap.docs) {
        final data = doc.data();
        // Use 'name' field (e.g., "UG Year 3")
        String name = data['name'] ?? data['className'] ?? doc.id;
        loadedClasses[doc.id] = name;
      }
      print("✅ Loaded ${loadedClasses.length} Classes");

      if (mounted) {
        setState(() {
          _deptNames = loadedDepts;
          _classNames = loadedClasses;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching metadata: $e");
    }
  }

  // Helper to get Department Name safely
  String _getDeptName(String? id) {
    if (id == null || id.isEmpty || id == '-') return "No Dept";
    // Returns "Bcom" instead of "BCOM"
    return _deptNames[id] ?? id;
  }

  // Helper to get Class Name safely
  String _getClassName(String? id) {
    if (id == null || id.isEmpty || id == '-') return "No Class";
    // Returns "UG Year 3" instead of "BCOM_UG_YEAR3"
    return _classNames[id] ?? id;
  }

  // ======================================================
  // DELETE LOGIC
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
    if (authUid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(authUid)
          .delete();
    }
  }

  Future<void> _deleteTeacher(String uid, String name) async {
    final confirmed = await _confirmDelete(context, name);
    if (!confirmed) return;

    await FirebaseFirestore.instance.collection('teacher').doc(uid).delete();
    await FirebaseFirestore.instance.collection('users').doc(uid).delete();
  }

  // ======================================================
  // UI BUILD
  // ======================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Manage Users"),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),
      body: Column(
        children: [
          _searchBar(),
          _buildToggleButtons(),
          const SizedBox(height: 10),
          Expanded(
            child: _selectedView == 0 ? _studentsList() : _teachersList(),
          ),
        ],
      ),
    );
  }

  // ... (Toggle Buttons) ...
  Widget _buildToggleButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [_toggleOption("Students", 0), _toggleOption("Teachers", 1)],
      ),
    );
  }

  Widget _toggleOption(String text, int index) {
    final isSelected = _selectedView == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedView = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================
  // SEARCH BAR (With X Button)
  // ======================================================
  Widget _searchBar() {
    return Container(
      color: primaryBlue,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search by name or email...",
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = "");
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 0,
          ),
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
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final students = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(searchQuery) || email.contains(searchQuery);
        }).toList();

        if (students.isEmpty)
          return const Center(child: Text("No students found"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: students.length,
          itemBuilder: (context, index) => _studentCard(students[index]),
        );
      },
    );
  }

  Widget _studentCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'No Email';

    // ✅ Get Real Names (e.g. "Bcom", "UG Year 3")
    final deptName = _getDeptName(data['departmentId']);
    final className = _getClassName(data['classId']);

    final faceEnabled = data['face_enabled'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: faceEnabled
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: faceEnabled ? Colors.green : Colors.red,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    faceEnabled ? "Face Active" : "No Face Data",
                    style: TextStyle(
                      color: faceEnabled ? Colors.green : Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const Divider(height: 15),

            // ✅ Display Admission No, Real Class Name, Real Dept Name
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoChip(Icons.numbers, "Adm: ${doc.id}"),
                const SizedBox(height: 8), // Vertical Spacing
                _infoChip(Icons.class_, className),
                const SizedBox(height: 8), // Vertical Spacing
                _infoChip(Icons.school, deptName),
              ],
            ),

            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: _actionButton(
                "Delete",
                Icons.delete,
                () => _deleteStudent(doc.id, name),
                color: Colors.red,
              ),
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
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator());

        final teachers = snap.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final email = (data['email'] ?? '').toString().toLowerCase();
          return name.contains(searchQuery) || email.contains(searchQuery);
        }).toList();

        if (teachers.isEmpty)
          return const Center(child: Text("No teachers found"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: teachers.length,
          itemBuilder: (context, index) => _teacherCard(teachers[index]),
        );
      },
    );
  }

  Widget _teacherCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? 'Unknown';
    final email = data['email'] ?? 'No Email';

    // ✅ Get Real Dept Name
    final deptName = _getDeptName(data['departmentId']);
    final approved = data['isApproved'] == true;

    // ✅ Classes Logic
    final List<dynamic> classIds = data['classIds'] ?? [];
    final int classCount = classIds.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Icon(
                  approved ? Icons.verified : Icons.pending,
                  color: approved ? primaryBlue : Colors.orange,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const Divider(height: 15),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoChip(Icons.school, deptName),

                if (classCount > 0) ...[
                  const SizedBox(height: 15), // Vertical Spacing
                  InkWell(
                    onTap: () => _showAssignedClasses(context, name, classIds),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.list_alt,
                            size: 14,
                            color: Colors.deepOrange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "$classCount Classes",
                            style: const TextStyle(
                              color: Colors.deepOrange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: _actionButton(
                "Delete",
                Icons.delete,
                () => _deleteTeacher(doc.id, name),
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ======================================================
  // SHOW ASSIGNED CLASSES (SNACKBAR)
  // ======================================================
  void _showAssignedClasses(
    BuildContext context,
    String teacherName,
    List<dynamic> ids,
  ) {
    // Map IDs to Real Names (e.g. "• UG Year 3")
    final names = ids
        .map((id) => "• ${_getClassName(id.toString())}")
        .join("\n");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$teacherName's Classes:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(names, style: const TextStyle(color: Colors.white70)),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ======================================================
  // COMMON WIDGETS
  // ======================================================
  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    Color color = Colors.blue,
  }) {
    return SizedBox(
      height: 32,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

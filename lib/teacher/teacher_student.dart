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
  // Theme Colors
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color bgLight = const Color(0xFFF5F7FA);
  final Color textDark = const Color(0xFF263238);
  final Color textGrey = const Color(0xFF78909C);

  String? departmentId;
  String? selectedClassId;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  // --------------------------------------------------
  // LOAD TEACHER PROFILE
  // --------------------------------------------------
  Future<void> _loadTeacherProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await _db.collection('teacher').doc(user.uid).get();
      if (!snap.exists) return;

      final data = snap.data()!;
      setState(() {
        departmentId = data['departmentId'];
        selectedClassId = data['classId'];
        isLoading = false;
      });
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  // --------------------------------------------------
  // UI BUILD
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: Text(
          "Students & Parents",
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : Column(
              children: [
                _classDropdown(),
                Expanded(child: _studentsList()),
              ],
            ),
    );
  }

  // --------------------------------------------------
  // CLASS DROPDOWN
  // --------------------------------------------------
  Widget _classDropdown() {
    if (departmentId == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          final valid = classes.any((doc) => doc.id == selectedClassId);

          return DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: valid ? selectedClassId : null,
              hint: const Text("Select Class"),
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: primaryBlue),
              items: classes.map((doc) {
                return DropdownMenuItem(
                  value: doc.id,
                  child: Text(
                    doc['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => selectedClassId = val),
            ),
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // STUDENT LIST
  // --------------------------------------------------
  Widget _studentsList() {
    if (selectedClassId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("Please select a class", style: TextStyle(color: textGrey)),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('student')
          .where('classId', isEqualTo: selectedClassId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: primaryBlue));
        }

        final students = snapshot.data!.docs;
        if (students.isEmpty) {
          return Center(
            child: Text("No students found", style: TextStyle(color: textGrey)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: students.length,
          itemBuilder: (context, index) {
            final doc = students[index];
            final data = doc.data() as Map<String, dynamic>;

            final name = data['name'] ?? 'Unknown';
            final admissionNo = data['admissionNo'] ?? doc.id;
            final email = data['email'] ?? 'No Email';

            return FutureBuilder<QuerySnapshot>(
              future: _db
                  .collection('parents')
                  .where('linked_student_id', isEqualTo: admissionNo)
                  .limit(1)
                  .get(),
              builder: (context, parentSnap) {
                final bool parentLinked =
                    parentSnap.hasData && parentSnap.data!.docs.isNotEmpty;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showParentPopup(context, admissionNo),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Initial Avatar
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: primaryBlue.withOpacity(0.1),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: primaryBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Details Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name
                                  Text(
                                    name,
                                    style: TextStyle(
                                      color: textDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  // ID
                                  _infoRow(
                                    Icons.badge_outlined,
                                    "ID: $admissionNo",
                                  ),
                                  const SizedBox(height: 4),
                                  // Email
                                  _infoRow(Icons.email_outlined, email),
                                  const SizedBox(height: 6),
                                  // Parent Status
                                  Row(
                                    children: [
                                      Icon(
                                        parentLinked
                                            ? Icons.link
                                            : Icons.link_off,
                                        size: 14,
                                        color: parentLinked
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        parentLinked
                                            ? "Parent Linked"
                                            : "No Parent Linked",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: parentLinked
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Arrow
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.grey.shade400,
                              size: 23,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textGrey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: textGrey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // PARENT POPUP
  // --------------------------------------------------
  Future<void> _showParentPopup(
    BuildContext context,
    String admissionNo,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final snap = await _db
          .collection('parents')
          .where('linked_student_id', isEqualTo: admissionNo)
          .limit(1)
          .get();

      if (context.mounted) Navigator.pop(context); // Close loading

      if (!context.mounted) return;

      if (snap.docs.isEmpty) {
        _showInfoDialog(
          context,
          "Parent Not Found",
          "No parent account is currently linked to this student.",
        );
        return;
      }

      final data = snap.docs.first.data();

      showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.family_restroom, color: primaryBlue),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Parent Details",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _popupRow("Name", data['name'] ?? 'N/A'),
                const Divider(height: 24),
                _popupRow("Email", data['email'] ?? 'N/A'),
                const Divider(height: 24),
                _popupRow("Phone", data['mobile'] ?? 'N/A'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Close",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      _showInfoDialog(context, "Error", "Could not fetch details.");
    }
  }

  Widget _popupRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: textGrey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showInfoDialog(BuildContext context, String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

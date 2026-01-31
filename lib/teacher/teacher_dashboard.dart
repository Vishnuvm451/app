import 'package:darzo/attendance/attendance_daily.dart';
import 'package:darzo/settings.dart';
import 'package:darzo/teacher/edit_setup.dart';
import 'package:darzo/teacher/internal.dart';
import 'package:darzo/attendance/start_attendance.dart';
import 'package:darzo/teacher/teacher_student.dart';
import 'package:darzo/time_table_selection.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/login.dart';
import 'teacher_setup_page.dart';
import 'package:darzo/notification/notifications.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  bool isLoading = true;

  String teacherName = '';
  String departmentId = '';

  // MULTI-SELECT SUPPORT
  List<String> classIds = [];
  List<String> subjectIds = [];

  bool setupCompleted = false;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Color primaryBlue = const Color(0xFF1E88E5);
  final Color bgWhite = const Color(0xFFF5F7FA);

  @override
  void initState() {
    super.initState();
    _loadTeacher();
  }

  // --------------------------------------------------
  // LOAD TEACHER PROFILE
  // --------------------------------------------------
  Future<void> _loadTeacher() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await _db.collection('teacher').doc(uid).get();

      if (!mounted) return;

      if (!snap.exists) {
        _showSnack("Teacher profile not found. Contact admin.");
        await _logout();
        return;
      }

      final data = snap.data()!;

      if (data['isApproved'] != true) {
        _showSnack("Your account is not approved");
        await _logout();
        return;
      }

      if (data['setupCompleted'] != true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherSetupPage()),
        );
        return;
      }

      setState(() {
        teacherName = data['name'] ?? '';
        departmentId = data['departmentId'] ?? '';

        classIds = List<String>.from(data['classIds'] ?? []);
        subjectIds = List<String>.from(data['subjectIds'] ?? []);

        setupCompleted = true;
        isLoading = false;
      });

      print("✅ Teacher loaded: $teacherName");
      print("📍 Classes: $classIds");
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ✅ NEW: Refresh function for pull-to-refresh
  Future<void> _refreshDashboard() async {
    print("🔄 Refreshing teacher dashboard...");
    await _loadTeacher();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: bgWhite,
        body: Center(child: CircularProgressIndicator(color: primaryBlue)),
      );
    }

    return Scaffold(
      backgroundColor: primaryBlue,
      // ✅ NEW: Wrap body with RefreshIndicator for pull-to-refresh
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        color: primaryBlue,
        backgroundColor: Colors.white,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: bgWhite,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Quick Actions",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _quickActionsGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Dashboard",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Teacher Panel",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Colors.white,
                  size: 34,
                ),
                onPressed: _logout,
              ),
            ],
          ),
          const SizedBox(height: 30),
          _buildProfileRow(),
        ],
      ),
    );
  }

  Widget _buildProfileRow() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white,
          child: Icon(Icons.person, color: Colors.blue, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hello, $teacherName",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _infoBadge(
                    departmentId.isEmpty
                        ? "No Dept"
                        : departmentId.replaceAll('_', ' ').toUpperCase(),
                  ),
                  const SizedBox(width: 8),
                  _infoBadge("${classIds.length} Classes"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _quickActionsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _actionCard(
          icon: Icons.qr_code_scanner_rounded,
          label: "Start\nAttendance",
          color: const Color(0xFF2196F3),
          onTap: () {
            if (classIds.isEmpty) {
              _showSnack("No classes assigned. Edit Setup.");
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TeacherAttendanceSessionPage(),
              ),
            );
          },
        ),
        _actionCard(
          icon: Icons.checklist_rtl_rounded,
          label: "Mark\nAttendance",
          color: const Color(0xFFFF9800),
          onTap: () =>
              _pickClassAndNavigate((id) => ManualAttendancePage(classId: id)),
        ),
        _actionCard(
          icon: Icons.edit_note_rounded,
          label: "Internal\nMarks",
          color: const Color(0xFF9C27B0),
          onTap: () => _pickClassAndNavigate(
            (id) => AddInternalMarksPage(classId: id, subjectId: 'default'),
          ),
        ),
        _actionCard(
          icon: Icons.group_rounded,
          label: "My\nStudents",
          color: const Color(0xFF4CAF50),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeacherStudentsListPage()),
          ),
        ),
        _actionCard(
          icon: Icons.settings_suggest_rounded,
          label: "Edit\nSetup",
          color: const Color(0xFF009688),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditSetupPage()),
          ),
        ),
        _actionCard(
          icon: Icons.edit_calendar_rounded,
          label: "Edit\nTimetable",
          color: Colors.purple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TimetableSelectionPage(isAdmin: false),
              ),
            );
          },
        ),
        _actionCard(
          icon: Icons.notifications_active_rounded,
          label: "Notification\nAlerts",
          color: const Color(0xFF009688),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SendNotificationPage(senderRole: 'Teacher'),
            ),
          ),
        ),
        _actionCard(
          icon: Icons.settings,
          label: "Settings",
          color: Colors.blueGrey,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsPage(
                userRole: 'teacher',
                initialName: teacherName,
                initialSubTitle:
                    "Dept: ${departmentId.replaceAll('_', ' ').toUpperCase()}",
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              radius: 28,
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // FIXED CLASS PICKER (SHOWS NAMES)
  // --------------------------------------------------
  void _pickClassAndNavigate(Widget Function(String) pageBuilder) {
    if (classIds.isEmpty) {
      _showSnack("No classes assigned. Edit Setup.");
      return;
    }

    // Direct navigation if only 1 class
    if (classIds.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => pageBuilder(classIds.first)),
      );
      return;
    }

    // Show Bottom Sheet with FutureBuilder to fetch names
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(15),
          // Height constraint for large lists
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Select Class",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<DocumentSnapshot>>(
                  // Fetch all class documents for the IDs we have
                  future: _fetchClassDetails(classIds),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      // Fallback to IDs if fetch fails
                      return ListView(
                        children: classIds
                            .map(
                              (id) => _buildListTile(id, id, null, pageBuilder),
                            )
                            .toList(),
                      );
                    }

                    final classDocs = snapshot.data!;

                    return ListView.builder(
                      itemCount: classDocs.length,
                      itemBuilder: (ctx, index) {
                        final doc = classDocs[index];
                        final data = doc.data() as Map<String, dynamic>?;

                        final className =
                            data?['className'] ?? data?['name'] ?? doc.id;
                        final subjectName =
                            data?['subjectName']; // Might be null

                        return _buildListTile(
                          doc.id,
                          className,
                          subjectName,
                          pageBuilder,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper to build list tiles
  Widget _buildListTile(
    String id,
    String title,
    String? subtitle,
    Widget Function(String) pageBuilder,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.class_outlined, color: Colors.blue),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: Colors.grey[600]))
          : null,
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => pageBuilder(id)),
        );
      },
    );
  }

  // Helper to fetch documents
  Future<List<DocumentSnapshot>> _fetchClassDetails(List<String> ids) async {
    // Note: 'whereIn' is limited to 10 items. For robustness with large lists,
    // we fetch individually using Future.wait. It's safer for "My Classes" lists.
    List<Future<DocumentSnapshot>> futures = [];
    for (String id in ids) {
      futures.add(_db.collection('class').doc(id).get());
    }
    return await Future.wait(futures);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

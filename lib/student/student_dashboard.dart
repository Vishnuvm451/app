import 'dart:async';
import 'package:darzo/attendance/attendance_summary.dart';
import 'package:darzo/notification/notification_service.dart';
import 'package:darzo/notification/notification_view_page.dart';
import 'package:darzo/settings.dart';
import 'package:darzo/student/mark_attendance_face.dart';
import 'package:darzo/student/student_internal_marks_page.dart';
import 'package:darzo/student/view_classmates_page.dart';
import 'package:darzo/student/student_timetable_page.dart';
import 'package:darzo/student/view_teachers_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:darzo/login.dart';
import 'package:darzo/auth/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  bool isLoading = true;

  // Data Variables
  String studentName = "Loading...";
  String admissionNo = "";
  String classId = "";
  String departmentId = "";
  String currentSemester = "";
  String studentDocId = "";
  String debugMsg = "Initializing...";
  int _unreadNotificationCount = 0;

  // Timer Management
  Timer? _countdownTimer;
  String _remainingTime = "";
  bool _sessionExpired = false;

  // ✅ FIX: Cache today's date to avoid recalculating
  late String _todayCache;
  bool _debugPrinted = false;

  @override
  void initState() {
    super.initState();
    _todayCache = _getTodayId();
    _initDashboardData();
    _listenToUnreadNotifications();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _listenToUnreadNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('student')
        .where('authUid', isEqualTo: user.uid)
        .limit(1)
        .snapshots()
        .listen((query) {
          if (query.docs.isNotEmpty) {
            final studentDocId = query.docs.first.id;
            FirebaseFirestore.instance
                .collection('student')
                .doc(studentDocId)
                .collection('notifications')
                .where('isRead', isEqualTo: false)
                .snapshots()
                .listen((snapshot) {
                  if (mounted) {
                    setState(() {
                      _unreadNotificationCount = snapshot.docs.length;
                    });
                  }
                });
          }
        });
  }

  void _startCountdownTimer(DateTime expiresAt) {
    _countdownTimer?.cancel();
    _sessionExpired = false;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final now = DateTime.now();
      final remaining = expiresAt.difference(now);

      if (remaining.isNegative) {
        _countdownTimer?.cancel();
        setState(() {
          _remainingTime = "Expired";
          _sessionExpired = true;
        });
        return;
      }

      final hours = remaining.inHours;
      final minutes = remaining.inMinutes % 60;
      final seconds = remaining.inSeconds % 60;

      String timeStr;
      if (hours > 0) {
        timeStr = "${hours}h ${minutes}m ${seconds}s";
      } else if (minutes > 0) {
        timeStr = "${minutes}m ${seconds}s";
      } else {
        timeStr = "${seconds}s";
      }

      if (timeStr != _remainingTime) {
        setState(() {
          _remainingTime = timeStr;
        });
      }
    });
  }

  Future<void> _initDashboardData() async {
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logout();
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();

        if (mounted) {
          setState(() {
            studentName = data['name'] ?? "Student";
            admissionNo = data['admissionNo'] ?? doc.id;
            classId = (data['classId'] ?? "").trim();
            departmentId = data['departmentId'] ?? "";
            currentSemester = data['semester'] ?? "Semester 6";
            studentDocId = doc.id;
            isLoading = false;
            debugMsg = "Success";
          });

          // Initialize Notifications
          await NotificationService().initialize(
            role: 'student',
            id: admissionNo,
          );

          // Print debug info once
          if (!_debugPrinted) {
            _debugPrinted = true;
            debugPrint("✅ DASHBOARD LOADED SUCCESSFULLY");
            debugPrint("   studentName: $studentName");
            debugPrint("   admissionNo: $admissionNo");
            debugPrint("   classId: $classId");
            debugPrint("   todayId: $_todayCache");
          }
        }
      } else {
        if (mounted) {
          setState(() {
            isLoading = false;
            debugMsg = "No Profile Found";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          debugMsg = "Error: $e";
        });
      }
    }
  }

  Future<void> _logout() async {
    await context.read<AppAuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _navigateToTimetable() {
    if (classId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Class not assigned yet.")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentTimetablePage(
          classId: classId,
          currentSemester: currentSemester,
        ),
      ),
    );
  }

  // ✅ FIX: Simple date getter without logging
  String _getTodayId() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _isSessionValid(Map<String, dynamic> sessionData) {
    try {
      final dynamic expiresAtRaw = sessionData['expiresAt'];
      if (expiresAtRaw == null) return true;
      if (expiresAtRaw is! Timestamp) return true;

      final Timestamp expiresAt = expiresAtRaw;
      final now = DateTime.now();
      final expireTime = expiresAt.toDate();
      final isValid = expireTime.isAfter(now);

      if (isValid) {
        _startCountdownTimer(expireTime);
      }
      return isValid;
    } catch (e) {
      return true;
    }
  }

  // ================= BUILD UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: const Text(
          "Student Dashboard",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 13.0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, size: 35, color: Colors.white),
              ),
              onPressed: _logout,
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: _refreshDashboard,
                color: const Color(0xFF2196F3),
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                  child: Column(
                    children: [
                      _header(),
                      const SizedBox(height: 24),
                      _attendanceCard(),
                      const SizedBox(height: 24),
                      _quickActions(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _refreshDashboard() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() {});
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          ),
          child: const CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            child: Icon(Icons.school, size: 40, color: Color(0xFF2196F3)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Welcome, $studentName",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        if (departmentId.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              departmentId.replaceAll('_', ' '),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  // ================= ATTENDANCE CARD =================
  Widget _attendanceCard() {
    if (classId.isEmpty || studentDocId.isEmpty) {
      return _buildCardUI(
        text: "Profile Error",
        subtitle: debugMsg,
        color: Colors.red,
        canMark: false,
        buttonText: "Retry",
        remainingTime: "",
        isMarked: false,
        onRetry: _initDashboardData,
      );
    }

    // ✅ FIX: Use cached today value
    final today = _todayCache;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .where('date', isEqualTo: today)
          .snapshots(includeMetadataChanges: false),
      builder: (context, sessionSnap) {
        if (sessionSnap.hasError) {
          return _buildCardUI(
            text: "Error Loading Session",
            subtitle: "Check your connection",
            color: Colors.red,
            canMark: false,
            buttonText: "Error",
            remainingTime: "",
            isMarked: false,
          );
        }

        if (!sessionSnap.hasData) {
          return _buildCardUI(
            text: "Loading...",
            subtitle: "Checking for sessions",
            color: Colors.grey,
            canMark: false,
            buttonText: "Loading",
            remainingTime: "",
            isMarked: false,
          );
        }

        if (sessionSnap.data!.docs.isEmpty) {
          _countdownTimer?.cancel();
          _remainingTime = "";
          _sessionExpired = false;

          return _buildCardUI(
            text: "No Active Session",
            subtitle: "Waiting for teacher...",
            color: Colors.grey,
            canMark: false,
            buttonText: "Waiting",
            remainingTime: "",
            isMarked: false,
          );
        }

        final sessionDoc = sessionSnap.data!.docs.first;
        final sessionData = sessionDoc.data() as Map<String, dynamic>;

        if (!_isSessionValid(sessionData)) {
          if (!_sessionExpired) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _remainingTime = "Expired";
                  _sessionExpired = true;
                });
              }
            });
          }

          return _buildCardUI(
            text: "Session Expired",
            subtitle: "Teacher needs to start a new session",
            color: Colors.orange,
            canMark: false,
            buttonText: "Closed",
            remainingTime: _remainingTime,
            isMarked: false,
          );
        }

        final sessionType = sessionData['sessionType'] ?? 'unknown';
        final attendanceDocId = "${classId}_${today}_$sessionType";

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('attendance')
              .doc(attendanceDocId)
              .collection('student')
              .doc(admissionNo)
              .snapshots(includeMetadataChanges: false),
          builder: (context, attendanceSnap) {
            final isAlreadyMarked =
                attendanceSnap.hasData && attendanceSnap.data!.exists;

            if (isAlreadyMarked) {
              final attendanceData =
                  attendanceSnap.data!.data() as Map<String, dynamic>;
              final markedAt = attendanceData['markedAt'] as Timestamp?;

              _countdownTimer?.cancel();

              return _buildCardUI(
                text: "Present Today ✅",
                subtitle: markedAt != null
                    ? "Marked at ${DateFormat('hh:mm a').format(markedAt.toDate())}"
                    : "Attendance already marked",
                color: Colors.green,
                canMark: false,
                buttonText: "Marked",
                remainingTime: _remainingTime,
                isMarked: true,
              );
            }

            return _buildCardUI(
              text: "Mark Attendance",
              subtitle: "${_capitalize(sessionType)} Session Active",
              color: const Color(0xFF2196F3),
              canMark: true,
              buttonText: "Mark Now",
              remainingTime: _remainingTime,
              isMarked: false,
            );
          },
        );
      },
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildCardUI({
    required String text,
    String subtitle = "",
    required Color color,
    required bool canMark,
    required String buttonText,
    required String remainingTime,
    required bool isMarked,
    VoidCallback? onRetry,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          if (remainingTime.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _sessionExpired
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _sessionExpired ? Icons.timer_off : Icons.timer,
                    size: 14,
                    color: _sessionExpired ? Colors.red : Colors.green,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    remainingTime,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _sessionExpired ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  onRetry ??
                  (canMark
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MarkAttendancePage(),
                            ),
                          );
                        }
                      : null),
              style: ElevatedButton.styleFrom(
                backgroundColor: canMark
                    ? const Color(0xFF2196F3)
                    : Colors.grey.shade100,
                foregroundColor: canMark ? Colors.white : Colors.grey.shade500,
                elevation: canMark ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: Colors.grey.shade100,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isMarked
                        ? Icons.check_circle
                        : Icons.face_retouching_natural,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= QUICK ACTIONS =================
  Widget _quickActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "Quick Actions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: [
              _actionCard(
                icon: Icons.bar_chart_rounded,
                label: "Attendance\nSummary",
                color: const Color(0xFF2196F3),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MonthlyAttendanceSummaryPage(),
                  ),
                ),
              ),
              _actionCard(
                icon: Icons.assignment_rounded,
                label: "Internal\nMarks",
                color: const Color(0xFF9C27B0),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentInternalMarksPage(),
                  ),
                ),
              ),
              _actionCard(
                icon: Icons.group_rounded,
                label: "Classmates",
                color: const Color(0xFF4CAF50),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViewClassmatesPage()),
                ),
              ),
              _actionCard(
                icon: Icons.calendar_month_rounded,
                label: "Timetable",
                color: const Color(0xFFFF9800),
                onTap: _navigateToTimetable,
              ),
              _actionCard(
                icon: Icons.person_search_rounded,
                label: "Teachers",
                color: const Color(0xFF009688),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ViewTeachersPage()),
                ),
              ),
              _actionCard(
                icon: Icons.settings_rounded,
                label: "Settings",
                color: Colors.blueGrey,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsPage(
                      userRole: 'student',
                      initialName: studentName,
                      initialSubTitle: "Adm No: $admissionNo",
                    ),
                  ),
                ),
              ),
              _actionCard(
                icon: Icons.notifications_active_rounded,
                label: "Notifications",
                color: Colors.red,
                badgeCount: _unreadNotificationCount,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationViewPage(),
                  ),
                ),
              ),
              _actionCard(
                icon: Icons.chat_bubble_rounded,
                label: "Chat",
                color: Colors.pink,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat feature coming soon! 🚀'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= ACTION CARD =================
  Widget _actionCard({
    required IconData icon,
    required String label,
    required Color color,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 28, color: color),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

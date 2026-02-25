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

// ✅ Added Location Imports
import 'package:darzo/auth/location_config.dart';
import 'package:geolocator/geolocator.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  bool isLoading = true;

  // ✅ Location Checking Hook
  bool _isCheckingLocation = false;

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

  // ================= DATA FETCHING =================

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

          await NotificationService().initialize(
            role: 'student',
            id: admissionNo,
          );

          if (!_debugPrinted) {
            _debugPrinted = true;
            debugPrint("✅ DASHBOARD LOADED SUCCESSFULLY");
            debugPrint("   studentName: $studentName");
            debugPrint("   admissionNo: $admissionNo");
            debugPrint("   classId: $classId");
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

  // ================= ATTENDANCE LOGIC =================

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

  // ---------------------------------------------------------
  // 🚨 REPORT ISSUE MODULE
  // ---------------------------------------------------------
  Future<void> _reportIssue() async {
    if (classId.isEmpty || studentDocId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Report Issue?"),
        content: const Text(
          "Can't scan your face? Click 'Report' to notify your teacher. "
          "They will verify your attendance manually.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Report"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final today = _getTodayId();
      final sessionSnap = await FirebaseFirestore.instance
          .collection('attendance_session')
          .where('classId', isEqualTo: classId)
          .where('isActive', isEqualTo: true)
          .where('date', isEqualTo: today)
          .limit(1)
          .get();

      if (sessionSnap.docs.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No active attendance session found.")),
        );
        return;
      }

      final sessionId = sessionSnap.docs.first.id;
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await FirebaseFirestore.instance.collection('attendance_issues').add({
        'studentId': user.uid,
        'studentName': studentName,
        'admissionNo': admissionNo,
        'classId': classId,
        'sessionId': sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
          title: const Text("Sent!"),
          content: const Text(
            "Informed to teacher. Please wait for manual verification.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // ================= 📍 LOCATION LOGIC =================
  Future<void> _verifyLocationAndMarkAttendance() async {
    // Prevent double clicking
    if (_isCheckingLocation) return;

    setState(() => _isCheckingLocation = true);

    try {
      // Permission Check
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw "Location permissions are denied.";
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw "Location permissions are permanently denied. Enable them in settings.";
      }

      // Get Position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Calculate Distance
      double distanceInMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        LocationConfig.collegeLat,
        LocationConfig.collegeLng,
      );

      debugPrint("📏 Dist: ${distanceInMeters.toStringAsFixed(0)}m");

      // Validate Radius
      if (distanceInMeters <= LocationConfig.allowedRadiusMeters) {
        if (mounted) {
          setState(() => _isCheckingLocation = false);
          _proceedToMarkAttendance();
        }
      } else {
        throw "You are ${distanceInMeters.toInt()}m away from campus.\nMust be within ${LocationConfig.allowedRadiusMeters.toInt()}m.";
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingLocation = false);
        _showNeatLocationDialog(
          isError: true,
          title: "Location Error",
          message: e.toString().replaceAll("Exception: ", ""),
        );
      }
    }
  }

  void _proceedToMarkAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MarkAttendancePage()),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Location Verified! Starting Face Scan..."),
      ),
    );
  }

  void _showNeatLocationDialog({
    required bool isError,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isError ? Colors.red.shade50 : Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.location_off : Icons.check_circle,
                  size: 40,
                  color: isError ? Colors.red : const Color(0xFF2196F3),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Okay",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= UI WIDGETS =================

  Future<void> _refreshDashboard() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() {});
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

  // ---------------- ATTENDANCE CARD ----------------
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
            subtitle: "Check connection",
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

            // ✅ ACTIVE SESSION: Show Location Loading Hook
            return _buildCardUI(
              text: "Mark Attendance",
              subtitle: "${_capitalize(sessionType)} Session Active",
              color: const Color(0xFF2196F3),
              canMark: true,
              buttonText: _isCheckingLocation
                  ? "Checking Location..."
                  : "Mark Now",
              remainingTime: _remainingTime,
              isMarked: false,
              isLoading:
                  _isCheckingLocation, // Pass state to disable button & show spinner
              onRetry:
                  _verifyLocationAndMarkAttendance, // Overrides the generic push
              extraAction: TextButton.icon(
                onPressed: _reportIssue,
                icon: const Icon(
                  Icons.report_problem_outlined,
                  color: Colors.orange,
                  size: 18,
                ),
                label: const Text(
                  "Facing Issue?",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  backgroundColor: Colors.orange.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.orange.shade200),
                  ),
                ),
              ),
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

  // ✅ ADDED `isLoading` TO PARAMETERS
  Widget _buildCardUI({
    required String text,
    String subtitle = "",
    required Color color,
    required bool canMark,
    required String buttonText,
    required String remainingTime,
    required bool isMarked,
    VoidCallback? onRetry,
    Widget? extraAction,
    bool isLoading = false,
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
              // ✅ Disable button entirely when loading
              onPressed: isLoading
                  ? null
                  : (onRetry ??
                        (canMark
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const MarkAttendancePage(),
                                  ),
                                );
                              }
                            : null)),
              style: ElevatedButton.styleFrom(
                backgroundColor: canMark
                    ? const Color(0xFF2196F3)
                    : Colors.grey.shade100,
                foregroundColor: canMark ? Colors.white : Colors.grey.shade500,
                elevation: canMark ? 4 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: canMark
                    ? const Color(0xFF2196F3).withOpacity(
                        0.7,
                      ) // Keep blueish tint while loading
                    : Colors.grey.shade100,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✅ Handle Icon vs Spinner depending on isLoading state
                  if (isLoading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  else
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
          if (extraAction != null) ...[const SizedBox(height: 16), extraAction],
        ],
      ),
    );
  }

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
            ],
          ),
        ],
      ),
    );
  }

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
}

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._privateConstructor();
  static final FirestoreService instance =
      FirestoreService._privateConstructor();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ======================================================
  // USERS (ROLE SOURCE OF TRUTH)
  // ======================================================
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      if (!snap.exists) return null;
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  // ======================================================
  // STUDENTS
  // ======================================================
  Future<Map<String, dynamic>?> getStudent(String uid) async {
    try {
      final snap = await _db.collection('student').doc(uid).get();
      if (!snap.exists) return null;
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  // ======================================================
  // TEACHERS
  // ======================================================
  Future<Map<String, dynamic>?> getTeacher(String uid) async {
    try {
      final snap = await _db.collection('teacher').doc(uid).get();
      if (!snap.exists) return null;
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  // ======================================================
  // GET TODAY ATTENDANCE STATUS (FIXED)
  // ======================================================
  /// Returns:
  /// present | half-day | absent | not-marked | no-session
  Future<String?> getTodayAttendanceStatus({
    required String studentId,
    required String classId,
  }) async {
    try {
      final today = _todayId();

      // 1️⃣ Check attendance session
      final sessionSnap = await _db
          .collection('attendance_sessions')
          .doc('${classId}_$today')
          .get();

      if (!sessionSnap.exists) {
        return 'no-session';
      }

      // 2️⃣ Check student attendance (FIXED: students)
      final attendanceSnap = await _db
          .collection('attendance')
          .doc('${classId}_$today')
          .collection('students') // ✅ FIXED
          .doc(studentId)
          .get();

      if (!attendanceSnap.exists) {
        return 'not-marked';
      }

      return attendanceSnap.data()?['status'] ?? 'not-marked';
    } catch (_) {
      return 'not-marked'; // ✅ safer fallback
    }
  }

  // ======================================================
  // MARK ATTENDANCE (FACE / MANUAL)
  // ======================================================
  /// status → present | half-day | absent
  Future<void> markAttendance({
    required String studentId,
    required String classId,
    required String status,
  }) async {
    final today = _todayId();

    // 1️⃣ Ensure attendance session exists
    await _db.collection('attendance_sessions').doc('${classId}_$today').set({
      'classId': classId,
      'date': today,
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2️⃣ Save student attendance (students - plural)
    await _db
        .collection('attendance')
        .doc('${classId}_$today')
        .collection('students')
        .doc(studentId)
        .set({
          'studentId': studentId,
          'status': status,
          'marked_at': FieldValue.serverTimestamp(),
        });
  }

  // ======================================================
  // ATTENDANCE SUMMARY (STUDENT) - FIXED
  // ======================================================
  Future<Map<String, int>> getAttendanceSummary(String studentId) async {
    int present = 0;
    int absent = 0;
    int halfDay = 0;

    try {
      final snaps = await _db
          .collectionGroup('students') // ✅ FIXED
          .where('studentId', isEqualTo: studentId)
          .get();

      for (var doc in snaps.docs) {
        final status = doc['status'];
        if (status == 'present') present++;
        if (status == 'absent') absent++;
        if (status == 'half-day') halfDay++;
      }
    } catch (_) {}

    return {'present': present, 'absent': absent, 'half-day': halfDay};
  }

  // ======================================================
  // ADMIN / DEPARTMENT HELPERS
  // ======================================================
  Future<List<QueryDocumentSnapshot>> getDepartments() async {
    final snap = await _db.collection('departments').get();
    return snap.docs;
  }

  Future<List<QueryDocumentSnapshot>> getClassesByDepartment(
    String departmentId,
  ) async {
    final snap = await _db
        .collection('classes')
        .where('departmentId', isEqualTo: departmentId)
        .get();
    return snap.docs;
  }

  // ======================================================
  // PRIVATE HELPER
  // ======================================================
  String _todayId() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

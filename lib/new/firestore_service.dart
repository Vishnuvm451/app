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
      return snap.exists ? snap.data() : null;
    } catch (_) {
      return null;
    }
  }

  // ======================================================
  // STUDENTS
  // ======================================================
  Future<Map<String, dynamic>?> getStudent(String uid) async {
    try {
      final snap = await _db.collection('students').doc(uid).get();
      return snap.exists ? snap.data() : null;
    } catch (_) {
      return null;
    }
  }

  // ======================================================
  // TEACHERS
  // ======================================================
  Future<Map<String, dynamic>?> getTeacher(String uid) async {
    try {
      final snap = await _db.collection('teachers').doc(uid).get();
      return snap.exists ? snap.data() : null;
    } catch (_) {
      return null;
    }
  }

  // ======================================================
  // CHECK IF TODAY'S ATTENDANCE SESSION IS ACTIVE (TIME AWARE)
  // ======================================================
  Future<bool> isAttendanceActive({required String classId}) async {
    try {
      final today = _todayId();
      final sessionId = '${classId}_$today';

      final snap = await _db
          .collection('attendance_sessions')
          .doc(sessionId)
          .get();

      if (!snap.exists) return false;

      final data = snap.data();
      if (data == null) return false;

      if (data['isActive'] != true) return false;

      final Timestamp endTs = data['endTime'];
      final DateTime endTime = endTs.toDate();

      // ⏰ Auto close if time expired
      if (DateTime.now().isAfter(endTime)) {
        await _db.collection('attendance_sessions').doc(sessionId).update({
          'isActive': false,
        });
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  // ======================================================
  // GET TODAY ATTENDANCE STATUS
  // ======================================================
  /// Returns:
  /// present | half-day | absent | not-marked | no-session
  Future<String?> getTodayAttendanceStatus({
    required String studentId,
    required String classId,
  }) async {
    try {
      final today = _todayId();
      final sessionId = '${classId}_$today';

      // 1️⃣ Session must exist
      final sessionSnap = await _db
          .collection('attendance_sessions')
          .doc(sessionId)
          .get();

      if (!sessionSnap.exists) return 'no-session';

      // 2️⃣ Check student attendance
      final snap = await _db
          .collection('attendance')
          .doc(sessionId)
          .collection('students')
          .doc(studentId)
          .get();

      if (!snap.exists) return 'not-marked';

      return snap.data()?['status'] ?? 'not-marked';
    } catch (_) {
      return 'no-session';
    }
  }

  // ======================================================
  // MARK ATTENDANCE (FACE / MANUAL)
  // ======================================================
  /// status → present | half-day | absent
  /// method → face | manual
  Future<void> markAttendance({
    required String studentId,
    required String classId,
    required String status,
    required String method,
  }) async {
    final today = _todayId();
    final sessionId = '${classId}_$today';

    // ❗ DO NOT CREATE SESSION HERE
    // Session MUST be started by teacher

    await _db
        .collection('attendance')
        .doc(sessionId)
        .collection('students')
        .doc(studentId)
        .set({
          'studentId': studentId,
          'status': status,
          'method': method,
          'markedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // ======================================================
  // ATTENDANCE SUMMARY (STUDENT)
  // ======================================================
  Future<Map<String, int>> getAttendanceSummary(String studentId) async {
    int present = 0;
    int absent = 0;
    int halfDay = 0;

    try {
      final snaps = await _db
          .collectionGroup('students')
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
  // ADMIN HELPERS
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
  // PRIVATE DATE HELPER
  // ======================================================
  String _todayId() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

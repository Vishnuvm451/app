import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===================================================
  // USERS
  // ===================================================
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // ===================================================
  // STUDENT
  // ===================================================
  Future<Map<String, dynamic>?> getStudent(String uid) async {
    final snap = await _db
        .collection('student')
        .where('authUid', isEqualTo: uid)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  // ===================================================
  // TEACHER
  // ===================================================
  Future<Map<String, dynamic>?> getTeacher(String uid) async {
    final doc = await _db.collection('teacher').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // ===================================================
  // ATTENDANCE SESSION
  // ===================================================
  Future<bool> isAttendanceActive({
    required String classId,
    required String sessionType,
  }) async {
    final today = _todayId();
    final sessionId = '${classId}_${today}_$sessionType';

    final doc = await _db.collection('attendance_session').doc(sessionId).get();

    return doc.exists && doc['isActive'] == true;
  }

  // ===================================================
  // TODAY FINAL ATTENDANCE (STUDENT SAFE)
  // ===================================================
  Future<String?> getTodayFinalAttendance({
    required String studentId,
    required String classId,
  }) async {
    final today = _todayId();
    final docId = '${classId}_$today';

    final doc = await _db
        .collection('attendance_final')
        .doc(docId)
        .collection('student')
        .doc(studentId)
        .get();

    return doc.exists ? doc['status'] : null;
  }

  // ===================================================
  // MONTHLY ATTENDANCE SUMMARY (STUDENT SAFE)
  // ===================================================
  Future<Map<String, int>> getMonthlyAttendanceSummary({
    required String studentId,
    required List<String> attendanceDocIds,
  }) async {
    int present = 0;
    int halfDay = 0;
    int absent = 0;

    for (final docId in attendanceDocIds) {
      final doc = await _db
          .collection('attendance_final')
          .doc(docId)
          .collection('student')
          .doc(studentId)
          .get();

      if (!doc.exists) continue;

      switch (doc['status']) {
        case 'present':
          present++;
          break;
        case 'half-day':
          halfDay++;
          break;
        case 'absent':
          absent++;
          break;
      }
    }

    return {
      'present': present,
      'halfDay': halfDay,
      'absent': absent,
      'totalDays': present + halfDay + absent,
    };
  }

  // ===================================================
  // INTERNAL MARKS (STUDENT SAFE)
  // ===================================================
  Future<List<Map<String, dynamic>>> getStudentInternalMarks({
    required String studentId,
    required List<String> markDocIds,
  }) async {
    final List<Map<String, dynamic>> result = [];

    for (final docId in markDocIds) {
      final doc = await _db
          .collection('internal_mark')
          .doc(docId)
          .collection('student')
          .doc(studentId)
          .get();

      if (!doc.exists) continue;

      result.add({'marks': doc['marks']});
    }

    return result;
  }

  // ===================================================
  // HELPERS
  // ===================================================
  String _todayId() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}

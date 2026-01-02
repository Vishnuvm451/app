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
  // ATTENDANCE (SESSION CHECK)
  // ===================================================
  Future<bool> isAttendanceActive({
    required String classId,
    required String sessionType, // morning / afternoon
  }) async {
    final today = _todayId();
    final sessionId = '${classId}_${today}_$sessionType';

    final doc = await _db.collection('attendance_session').doc(sessionId).get();

    if (!doc.exists) return false;
    return doc['isActive'] == true;
  }

  // ===================================================
  // STUDENT TODAY FINAL ATTENDANCE
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

    if (!doc.exists) return null;
    return doc['status']; // present | half-day | absent
  }

  // ===================================================
  // MONTHLY ATTENDANCE SUMMARY
  // ===================================================
  Future<Map<String, int>> getMonthlyAttendanceSummary({
    required String studentId,
    required String classId,
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final startId = DateFormat('yyyy-MM-dd').format(start);
    final endId = DateFormat('yyyy-MM-dd').format(end);

    final snap = await _db
        .collection('attendance_final')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: startId)
        .where('date', isLessThanOrEqualTo: endId)
        .get();

    int present = 0;
    int halfDay = 0;
    int absent = 0;

    for (final doc in snap.docs) {
      final stuDoc = await doc.reference
          .collection('student')
          .doc(studentId)
          .get();

      if (!stuDoc.exists) continue;

      switch (stuDoc['status']) {
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
  // INTERNAL MARKS (STUDENT VIEW)
  // ===================================================
  Future<List<Map<String, dynamic>>> getStudentInternalMarks({
    required String studentId,
    required String classId,
  }) async {
    final snap = await _db
        .collection('internal_mark')
        .where('classId', isEqualTo: classId)
        .get();

    final List<Map<String, dynamic>> result = [];

    for (final doc in snap.docs) {
      final stuDoc = await doc.reference
          .collection('student')
          .doc(studentId)
          .get();

      if (!stuDoc.exists) continue;

      result.add({
        'subjectId': doc['subjectId'],
        'testName': doc['testName'],
        'totalMarks': doc['totalMarks'],
        'marks': stuDoc['marks'],
      });
    }

    return result;
  }

  // ===================================================
  // HELPERS
  // ===================================================
  String _todayId() {
    final now = DateTime.now();
    return DateFormat('yyyy-MM-dd').format(now);
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._private();
  static final FirestoreService instance = FirestoreService._private();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===================================================
  // USERS
  // ===================================================
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // ===================================================
  // STUDENT
  // ===================================================
  Future<Map<String, dynamic>?> getStudent(String uid) async {
    final doc = await _db.collection('students').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // ===================================================
  // TEACHER
  // ===================================================
  Future<Map<String, dynamic>?> getTeacher(String uid) async {
    final doc = await _db.collection('teacher').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  // ===================================================
  // TODAY FINAL ATTENDANCE (STUDENT DASHBOARD)
  // ===================================================
  Future<String?> getTodayFinalAttendance({
    required String studentId,
    required String classId,
  }) async {
    final today = _todayId();

    final doc = await _db
        .collection('attendance_final')
        .doc('${classId}_$today')
        .collection('students')
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

    int present = 0;
    int halfDay = 0;
    int absent = 0;
    int totalDays = 0;

    final snap = await _db
        .collection('attendance_final')
        .where('classId', isEqualTo: classId)
        .where('date', isGreaterThanOrEqualTo: _format(start))
        .where('date', isLessThanOrEqualTo: _format(end))
        .get();

    for (final dayDoc in snap.docs) {
      final stuSnap = await dayDoc.reference
          .collection('students')
          .doc(studentId)
          .get();

      if (!stuSnap.exists) continue;

      totalDays++;

      switch (stuSnap['status']) {
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
      'totalDays': totalDays,
    };
  }

  // ===================================================
  // CHECK IF ATTENDANCE SESSION IS ACTIVE (FACE ATTEND)
  // ===================================================
  Future<bool> isAttendanceActive({
    required String classId,
    required String sessionType, // morning | afternoon
  }) async {
    final today = _todayId();

    final doc = await _db
        .collection('attendance_sessions')
        .doc('${classId}_${today}_$sessionType')
        .get();

    if (!doc.exists) return false;
    return doc['isActive'] == true;
  }

  // ===================================================
  // SAVE FACE / MANUAL ATTENDANCE ENTRY
  // ===================================================
  Future<void> markAttendance({
    required String classId,
    required String studentId,
    required String sessionType,
    required String status, // present | half-day | absent
    required String method, // face | manual
  }) async {
    final today = _todayId();
    final sessionId = '${classId}_${today}_$sessionType';

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

  // ===================================================
  // INTERNAL MARKS (USED BY INTERNAL PAGES)
  // ===================================================
  Stream<QuerySnapshot> getStudentsByClass(String classId) {
    return _db
        .collection('students')
        .where('classId', isEqualTo: classId)
        .snapshots();
  }

  // ===================================================
  // HELPERS
  // ===================================================
  String _todayId() {
    final now = DateTime.now();
    return _format(now);
  }

  String _format(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

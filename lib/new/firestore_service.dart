import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /* ======================================================
   * USERS (COMMON)
   * ====================================================== */

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  /* ======================================================
   * DEPARTMENTS
   * ====================================================== */

  Future<List<Map<String, dynamic>>> getDepartments() async {
    final snap = await _db.collection('departments').orderBy('name').get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> createDepartment({
    required String id,
    required String name,
  }) async {
    await _db.collection('departments').doc(id).set({
      'name': name,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /* ======================================================
   * CLASSES
   * ====================================================== */

  Future<List<Map<String, dynamic>>> getClassesByDepartment(
    String departmentId,
  ) async {
    final snap = await _db
        .collection('classes')
        .where('departmentId', isEqualTo: departmentId)
        .orderBy('year')
        .get();

    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> createClass({
    required String id,
    required String departmentId,
    required String name,
    required int year,
    required String courseType, // UG / PG
  }) async {
    await _db.collection('classes').doc(id).set({
      'departmentId': departmentId,
      'name': name,
      'year': year,
      'courseType': courseType,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /* ======================================================
   * SUBJECTS
   * ====================================================== */

  Future<List<Map<String, dynamic>>> getSubjectsByClassAndSemester({
    required String departmentId,
    required int semester,
  }) async {
    final snap = await _db
        .collection('subjects')
        .where('departmentId', isEqualTo: departmentId)
        .where('semester', isEqualTo: semester)
        .orderBy('name')
        .get();

    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> createSubject({
    required String id,
    required String departmentId,
    required String name,
    required int semester,
  }) async {
    await _db.collection('subjects').doc(id).set({
      'departmentId': departmentId,
      'name': name,
      'semester': semester,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /* ======================================================
   * STUDENTS
   * ====================================================== */

  Future<Map<String, dynamic>?> getStudent(String uid) async {
    final doc = await _db.collection('students').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> createStudentProfile({
    required String uid,
    required String name,
    required String email,
    required String admissionNo,
    required String departmentId,
    required String classId,
    required String courseType,
  }) async {
    await _db.collection('students').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'admissionNo': admissionNo,
      'departmentId': departmentId,
      'classId': classId,
      'courseType': courseType,
      'faceEnabled': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /* ======================================================
   * TEACHERS
   * ====================================================== */

  Future<Map<String, dynamic>?> getTeacher(String uid) async {
    final doc = await _db.collection('teachers').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  Future<void> createTeacherRequest({
    required String name,
    required String email,
    required String departmentId,
  }) async {
    await _db.collection('teacher_requests').add({
      'name': name,
      'email': email,
      'departmentId': departmentId,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeTeacherSetup({
    required String uid,
    required String classId,
    required int semester,
    required List<String> subjectIds,
  }) async {
    await _db.collection('teachers').doc(uid).update({
      'teachingClassId': classId,
      'teachingSemester': semester,
      'subjectIds': subjectIds,
      'setupCompleted': true,
    });
  }

  /* ======================================================
   * ATTENDANCE (OPTION 1 – DEPARTMENT CENTRIC)
   * ====================================================== */

  /// CREATE ATTENDANCE SESSION (Teacher)
  Future<String> createAttendanceSession({
    required String departmentId,
    required String classId,
    required String subjectId,
    required String teacherId,
    required int semester,
  }) async {
    final doc = await _db.collection('attendance_sessions').add({
      'departmentId': departmentId,
      'classId': classId,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'semester': semester,
      'date': DateTime.now().toIso8601String().split('T')[0],
      'isActive': true,
      'created_at': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  /// CLOSE SESSION
  Future<void> closeAttendanceSession(String sessionId) async {
    await _db.collection('attendance_sessions').doc(sessionId).update({
      'isActive': false,
      'closed_at': FieldValue.serverTimestamp(),
    });
  }

  /// SAVE ATTENDANCE RECORD (Manual / Face)
  Future<void> createAttendanceRecord({
    required String sessionId,
    required String studentId,
    required String status, // present | absent | half-day
    required String markedBy, // manual | face
  }) async {
    await _db.collection('attendance_records').add({
      'sessionId': sessionId,
      'studentId': studentId,
      'status': status,
      'markedBy': markedBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> getTodayAttendanceStatus({
    required String studentId,
    required String classId,
  }) async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    // 1️⃣ Find today’s active session
    final sessionSnap = await _db
        .collection('attendance_sessions')
        .where('classId', isEqualTo: classId)
        .where('date', isEqualTo: today)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (sessionSnap.docs.isEmpty) {
      return 'no-session';
    }

    final sessionId = sessionSnap.docs.first.id;

    // 2️⃣ Check attendance record
    final recordSnap = await _db
        .collection('attendance_records')
        .where('sessionId', isEqualTo: sessionId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    if (recordSnap.docs.isEmpty) {
      return 'not-marked';
    }

    return recordSnap.docs.first['status']; // present / absent / half-day
  }

  /// CHECK DUPLICATE ATTENDANCE (Student Safety)
  Future<bool> hasStudentMarkedAttendance({
    required String sessionId,
    required String studentId,
  }) async {
    final snap = await _db
        .collection('attendance_records')
        .where('sessionId', isEqualTo: sessionId)
        .where('studentId', isEqualTo: studentId)
        .limit(1)
        .get();

    return snap.docs.isNotEmpty;
  }
}

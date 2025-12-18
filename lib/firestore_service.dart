// =======================================================
//  firestore_service.dart (TYPE SAFE & OPTIMIZED)
// =======================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===================================================
  // COLLECTION REFERENCES
  // ===================================================
  CollectionReference<Map<String, dynamic>> get users =>
      _db.collection('users');

  CollectionReference<Map<String, dynamic>> get departments =>
      _db.collection('departments');

  CollectionReference<Map<String, dynamic>> get classes =>
      _db.collection('classes');

  CollectionReference<Map<String, dynamic>> get subjects =>
      _db.collection('subjects');

  CollectionReference<Map<String, dynamic>> get students =>
      _db.collection('students');

  CollectionReference<Map<String, dynamic>> get teachers =>
      _db.collection('teachers');

  CollectionReference<Map<String, dynamic>> get teachingAssignments =>
      _db.collection('teaching_assignments');

  CollectionReference<Map<String, dynamic>> get attendanceSessions =>
      _db.collection('attendance_sessions');

  // ===================================================
  // USERS
  // ===================================================
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await users.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  // ===================================================
  // DEPARTMENTS
  // ===================================================
  Future<void> addDepartment({
    required String deptId,
    required String name,
  }) async {
    await departments.doc(deptId).set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getDepartments() async {
    final snap = await departments.orderBy('name').get();
    return snap.docs.map((e) => e.data()).toList();
  }

  // ===================================================
  // CLASSES
  // ===================================================
  Future<void> addClass({
    required String classId,
    required String name,
    required String departmentId,
    required String courseType,
    required int year,
  }) async {
    await classes.doc(classId).set({
      'name': name,
      'departmentId': departmentId,
      'courseType': courseType,
      'year': year,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getClasses({
    required String departmentId,
    required String courseType,
    required int year,
  }) async {
    final snap = await classes
        .where('departmentId', isEqualTo: departmentId)
        .where('courseType', isEqualTo: courseType)
        .where('year', isEqualTo: year)
        .get();

    return snap.docs.map((e) => e.data()).toList();
  }

  // ===================================================
  // SUBJECTS
  // ===================================================
  Future<void> addSubject({
    required String subjectId,
    required String name,
    required String departmentId,
    required String classId,
    required int semester,
  }) async {
    await subjects.doc(subjectId).set({
      'name': name,
      'departmentId': departmentId,
      'classId': classId,
      'semester': semester,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getSubjects({
    required String departmentId,
    required String classId,
    required int semester,
  }) async {
    final snap = await subjects
        .where('departmentId', isEqualTo: departmentId)
        .where('classId', isEqualTo: classId)
        .where('semester', isEqualTo: semester)
        .get();

    return snap.docs.map((e) => e.data()).toList();
  }

  // ===================================================
  // STUDENTS
  // ===================================================
  Future<Map<String, dynamic>?> getStudent(String uid) async {
    final doc = await students.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<List<Map<String, dynamic>>> getStudentsByClass({
    required String departmentId,
    required String classId,
  }) async {
    final snap = await students
        .where('departmentId', isEqualTo: departmentId)
        .where('classId', isEqualTo: classId)
        .get();

    return snap.docs.map((e) => e.data()).toList();
  }

  // ===================================================
  // TEACHERS
  // ===================================================
  Future<Map<String, dynamic>?> getTeacher(String uid) async {
    final doc = await teachers.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> approveTeacher(String uid) async {
    await teachers.doc(uid).update({
      'isApproved': true,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ===================================================
  // TEACHING ASSIGNMENTS
  // ===================================================
  Future<void> addTeachingAssignment({
    required Map<String, dynamic> data,
  }) async {
    await teachingAssignments.add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getTeacherAssignments(
    String teacherId,
  ) async {
    final snap = await teachingAssignments
        .where('teacherId', isEqualTo: teacherId)
        .get();

    return snap.docs.map((e) => e.data()).toList();
  }

  // ===================================================
  // ATTENDANCE SESSION
  // ===================================================
  Future<String> createAttendanceSession({
    required Map<String, dynamic> data,
  }) async {
    final doc = await attendanceSessions.add({
      ...data,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> closeAttendanceSession(String sessionId) async {
    await attendanceSessions.doc(sessionId).update({
      'isActive': false,
      'closedAt': FieldValue.serverTimestamp(),
    });
  }
}

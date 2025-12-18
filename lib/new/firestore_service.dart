import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =====================================================
  // USERS (ROLE DATA)
  // =====================================================
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return {'uid': uid, 'email': data['email'], 'role': data['role']};
  }

  // =====================================================
  // STUDENTS
  // =====================================================
  Future<void> createStudentProfile({
    required String uid,
    required String name,
    required String email,
    required String admissionNo,
    required String departmentId,
    required String classId,
    required String courseType,
  }) async {
    final batch = _db.batch();

    batch.set(_db.collection('users').doc(uid), {
      'uid': uid,
      'email': email,
      'role': 'student',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_db.collection('students').doc(uid), {
      'uid': uid,
      'name': name,
      'email': email,
      'admissionNo': admissionNo,
      'departmentId': departmentId,
      'classId': classId,
      'courseType': courseType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<Map<String, dynamic>?> getStudent(String uid) async {
    final doc = await _db.collection('students').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return {
      'uid': uid,
      'name': data['name'],
      'email': data['email'],
      'admissionNo': data['admissionNo'],
      'departmentId': data['departmentId'],
      'classId': data['classId'],
      'courseType': data['courseType'],
    };
  }

  // =====================================================
  // TEACHERS
  // =====================================================
  Future<Map<String, dynamic>?> getTeacher(String uid) async {
    final doc = await _db.collection('teachers').doc(uid).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    return {
      'uid': uid,
      'name': data['name'],
      'email': data['email'],
      'departmentId': data['departmentId'],
      'isApproved': data['isApproved'] ?? false,
      'setupCompleted': data['setupCompleted'] ?? false,
      'classIds': List<String>.from(data['classIds'] ?? []),
      'subjectIds': List<String>.from(data['subjectIds'] ?? []),
    };
  }

  Future<void> completeTeacherSetup({
    required String uid,
    required List<String> classIds,
    required List<String> subjectIds,
  }) async {
    await _db.collection('teachers').doc(uid).update({
      'classIds': classIds,
      'subjectIds': subjectIds,
      'setupCompleted': true,
      'setupAt': FieldValue.serverTimestamp(),
    });
  }

  // =====================================================
  // TEACHER REQUESTS (APPROVAL FLOW)
  // =====================================================
  Future<void> createTeacherRequest({
    required String name,
    required String email,
    required String password,
    required String departmentId,
  }) async {
    await _db.collection('teacher_requests').add({
      'name': name,
      'email': email,
      'password': password,
      'departmentId': departmentId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Map<String, dynamic>>> teacherRequestsStream() {
    return _db
        .collection('teacher_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          return snap.docs.map((doc) {
            final data = doc.data();
            return {'requestId': doc.id, ...data};
          }).toList();
        });
  }

  Future<void> approveTeacher({
    required String requestId,
    required String uid,
    required String name,
    required String email,
    required String departmentId,
  }) async {
    final batch = _db.batch();

    batch.set(_db.collection('users').doc(uid), {
      'uid': uid,
      'email': email,
      'role': 'teacher',
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_db.collection('teachers').doc(uid), {
      'uid': uid,
      'name': name,
      'email': email,
      'departmentId': departmentId,
      'isApproved': true,
      'setupCompleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection('teacher_requests').doc(requestId), {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'authUid': uid,
    });

    await batch.commit();
  }

  Future<void> rejectTeacher(String requestId) async {
    await _db.collection('teacher_requests').doc(requestId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  // =====================================================
  // DEPARTMENTS
  // =====================================================
  Future<List<Map<String, dynamic>>> getDepartments() async {
    final snap = await _db.collection('departments').orderBy('name').get();
    return snap.docs.map((d) {
      final data = d.data();
      return {'id': d.id, 'name': data['name']};
    }).toList();
  }

  Future<void> createDepartment({
    required String id,
    required String name,
  }) async {
    await _db.collection('departments').doc(id).set({
      'name': name,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // =====================================================
  // CLASSES
  // =====================================================
  Future<List<Map<String, dynamic>>> getClassesByDepartment(
    String departmentId,
  ) async {
    final snap = await _db
        .collection('classes')
        .where('departmentId', isEqualTo: departmentId)
        .orderBy('year')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'name': data['name'],
        'courseType': data['courseType'],
        'year': data['year'],
      };
    }).toList();
  }

  Future<void> createClass({
    required String id,
    required String name,
    required String departmentId,
    required String courseType,
    required int year,
  }) async {
    await _db.collection('classes').doc(id).set({
      'name': name,
      'departmentId': departmentId,
      'courseType': courseType,
      'year': year,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // =====================================================
  // SUBJECTS
  // =====================================================
  Future<List<Map<String, dynamic>>> getSubjects({
    required String departmentId,
    required String courseType,
    required int semester,
  }) async {
    final snap = await _db
        .collection('subjects')
        .where('departmentId', isEqualTo: departmentId)
        .where('courseType', isEqualTo: courseType)
        .where('semester', isEqualTo: semester)
        .orderBy('name')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return {'id': d.id, 'name': data['name'], 'semester': data['semester']};
    }).toList();
  }

  Future<void> createSubject({
    required String id,
    required String name,
    required String departmentId,
    required String courseType,
    required int semester,
  }) async {
    await _db.collection('subjects').doc(id).set({
      'name': name,
      'departmentId': departmentId,
      'courseType': courseType,
      'semester': semester,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

//  auth_service.dart

// Responsibilities:
// ✅ Firebase Auth (login / logout / register)
// ✅ Fetch & cache user role
// ✅ Teacher approval + setup checks
// ✅ ZERO UI code
// ✅ Single source of truth for auth logic
// =======================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  AuthService._private();
  static final AuthService instance = AuthService._private();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ===================================================
  //  CURRENT USER
  // ===================================================
  User? get currentUser => _auth.currentUser;

  // ===================================================
  //  LOGIN
  // ===================================================
  Future<User?> login({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    return cred.user;
  }

  // ===================================================
  //  LOGOUT
  // ===================================================
  Future<void> logout() async {
    await _auth.signOut();
  }

  // ===================================================
  //  GET USER ROLE (FETCH ONCE)
  // ===================================================
  Future<String?> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['role'];
  }

  // ===================================================
  //  STUDENT REGISTER (LINK ONLY)
  // ===================================================
  Future<void> registerStudent({
    required String email,
    required String password,
    required String admissionNo,
    required String departmentId,
    required String classId,
    required String courseType,
    String? departmentName,
    String? className,
  }) async {
    // Create auth account
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final uid = cred.user!.uid;

    // Atomic write
    await _db.runTransaction((tx) async {
      // users
      tx.set(_db.collection('users').doc(uid), {
        'uid': uid,
        'role': 'student',
        'admissionNo': admissionNo,
        'deptId': departmentId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // students
      tx.set(_db.collection('students').doc(uid), {
        'uid': uid,
        'admissionNo': admissionNo,
        'departmentId': departmentId,
        'departmentName': departmentName,
        'classId': classId,
        'className': className,
        'courseType': courseType,
        'face_enabled': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ===================================================
  //  TEACHER APPROVAL CHECK
  // ===================================================
  Future<bool> isTeacherApproved(String uid) async {
    final doc = await _db.collection('teachers').doc(uid).get();
    if (!doc.exists) return false;
    return doc.data()?['isApproved'] ?? false;
  }

  // ===================================================
  //  TEACHER SETUP CHECK (ONE-TIME PAGE)
  // ===================================================
  Future<bool> isTeacherSetupCompleted(String uid) async {
    final doc = await _db.collection('teachers').doc(uid).get();
    if (!doc.exists) return false;
    return doc.data()?['setupCompleted'] ?? false;
  }

  // ===================================================
  //  COMPLETE TEACHER SETUP
  // ===================================================
  Future<void> completeTeacherSetup({
    required String teacherId,
    required Map<String, dynamic> assignmentData,
  }) async {
    final batch = _db.batch();

    // Save teaching assignment
    final assignmentRef = _db.collection('teaching_assignments').doc();

    batch.set(assignmentRef, {
      ...assignmentData,
      'teacherId': teacherId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Mark setup completed
    batch.update(_db.collection('teachers').doc(teacherId), {
      'setupCompleted': true,
    });

    await batch.commit();
  }

  // ===================================================
  //  PASSWORD RESET (OPTIONAL)
  // ===================================================
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}

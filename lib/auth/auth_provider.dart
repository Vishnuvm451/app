import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:darzo/services/auth_service.dart';

class AppAuthProvider extends ChangeNotifier {
  // ===================================================
  // STATE
  // ===================================================
  User? _user;

  String? _role;
  String? _departmentId;
  String? _name;

  // Teacher flags
  bool _teacherApproved = false;
  bool _teacherSetupCompleted = false;

  // Parent flags
  String? _linkedStudentId;
  bool _childFaceLinked = false;

  bool _initialized = false;
  bool _isLoading = false;

  // ===================================================
  // GETTERS
  // ===================================================
  User? get user => _user;

  String? get role => _role;
  String? get departmentId => _departmentId;
  String? get name => _name;

  bool get isLoggedIn => _user != null;

  bool get isAdmin => _role == 'admin';
  bool get isStudent => _role == 'student';
  bool get isTeacher => _role == 'teacher';
  bool get isParent => _role == 'parent';

  bool get isTeacherApproved => _teacherApproved;
  bool get isTeacherSetupCompleted => _teacherSetupCompleted;

  String? get linkedStudentId => _linkedStudentId;
  bool get childFaceLinked => _childFaceLinked;

  bool get isInitialized => _initialized;
  bool get isLoading => _isLoading;

  // ===================================================
  // INIT (AUTO LOGIN)
  // ===================================================
  Future<void> init() async {
    try {
      _user = FirebaseAuth.instance.currentUser;

      if (_user != null) {
        await _user!.reload();
        _user = FirebaseAuth.instance.currentUser;

        if (_user != null) {
          await _loadUserProfile(_user!.uid);
        }
      }
    } catch (e) {
      debugPrint("❌ Init error: $e");
      _clearState();
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  // ===================================================
  // LOGIN
  // ===================================================
  Future<void> login({required String email, required String password}) async {
    _setLoading(true);

    try {
      final user = await AuthService.instance.login(
        email: email,
        password: password,
      );

      if (user == null) {
        throw Exception("Authentication failed");
      }

      await user.reload();
      _user = FirebaseAuth.instance.currentUser;

      await _loadUserProfile(_user!.uid);
    } finally {
      _setLoading(false);
    }
  }

  // ===================================================
  // LOGOUT
  // ===================================================
  Future<void> logout() async {
    await AuthService.instance.logout();
    _clearState();
    notifyListeners();
  }

  // ===================================================
  // LOAD USER PROFILE (🔥 FULLY FIXED)
  // ===================================================
  Future<void> _loadUserProfile(String uid) async {
    try {
      final firestore = FirebaseFirestore.instance;

      Map<String, dynamic>? data;
      String role = '';

      // --------------------------------------------------
      // 1️⃣ USERS COLLECTION (admin / student / teacher)
      // --------------------------------------------------
      final userDoc = await firestore.collection('users').doc(uid).get();

      if (userDoc.exists && userDoc.data()?['role'] != null) {
        role = userDoc.data()!['role'].toString().trim().toLowerCase();
        data = userDoc.data();
      }

      // --------------------------------------------------
      // 2️⃣ PARENT FALLBACK (parents/{uid})
      // --------------------------------------------------
      if (role.isEmpty) {
        final parentDoc = await firestore.collection('parents').doc(uid).get();

        if (parentDoc.exists) {
          role = 'parent';
          data = parentDoc.data();
        }
      }

      // --------------------------------------------------
      // 3️⃣ STUDENT FALLBACK (student.authUid == uid)
      // --------------------------------------------------
      if (role.isEmpty) {
        final studentSnap = await firestore
            .collection('student')
            .where('authUid', isEqualTo: uid)
            .limit(1)
            .get();

        if (studentSnap.docs.isNotEmpty) {
          role = 'student';
          data = studentSnap.docs.first.data();
        }
      }

      // --------------------------------------------------
      // 4️⃣ TEACHER FALLBACK (teacher/{uid})
      // --------------------------------------------------
      if (role.isEmpty) {
        final teacherDoc = await firestore.collection('teacher').doc(uid).get();

        if (teacherDoc.exists) {
          role = 'teacher';
          data = teacherDoc.data();
        }
      }

      if (role.isEmpty || data == null) {
        throw Exception("Invalid user role");
      }

      _role = role;

      // --------------------------------------------------
      // ADMIN
      // --------------------------------------------------
      if (role == 'admin') {
        _name = data['name'] ?? 'Admin';
        notifyListeners();
        return;
      }

      // --------------------------------------------------
      // STUDENT
      // --------------------------------------------------
      if (role == 'student') {
        _departmentId = data['departmentId'];
        _name = data['name'];
        notifyListeners();
        return;
      }

      // --------------------------------------------------
      // TEACHER
      // --------------------------------------------------
      if (role == 'teacher') {
        _teacherApproved = data['isApproved'] == true;
        _teacherSetupCompleted = data['setupCompleted'] == true;
        _departmentId = data['departmentId'];
        _name = data['name'];
        notifyListeners();
        return;
      }

      // --------------------------------------------------
      // PARENT ✅
      // --------------------------------------------------
      if (role == 'parent') {
        _name = data['name'] ?? 'Parent';
        _linkedStudentId = data['linked_student_id'];
        _childFaceLinked = data['child_face_linked'] == true;
        notifyListeners();
        return;
      }

      throw Exception("Invalid user role");
    } catch (e) {
      debugPrint("❌ Load user profile error: $e");
      rethrow;
    }
  }

  // ===================================================
  // HELPERS
  // ===================================================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearState() {
    _user = null;
    _role = null;
    _departmentId = null;
    _name = null;
    _teacherApproved = false;
    _teacherSetupCompleted = false;
    _linkedStudentId = null;
    _childFaceLinked = false;
  }
}

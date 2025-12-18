import 'package:darzo/auth_service.dart';
import 'package:darzo/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  // ===================================================
  // STATE
  // ===================================================
  User? _user;

  String? _role;
  String? _departmentId;

  bool _teacherApproved = false;
  bool _teacherSetupCompleted = false;

  bool _initialized = false;
  bool _isLoading = false;

  // ===================================================
  // GETTERS
  // ===================================================
  User? get user => _user;

  String? get role => _role;
  String? get departmentId => _departmentId;

  bool get isLoggedIn => _user != null;
  bool get isAdmin => _role == 'admin';
  bool get isStudent => _role == 'student';
  bool get isTeacher => _role == 'teacher';

  bool get isTeacherApproved => _teacherApproved;
  bool get isTeacherSetupCompleted => _teacherSetupCompleted;

  bool get isInitialized => _initialized;
  bool get isLoading => _isLoading;

  // ===================================================
  // INIT (APP START)
  // ===================================================
  Future<void> init() async {
    _user = FirebaseAuth.instance.currentUser;

    if (_user != null) {
      await _loadUserProfile(_user!.uid);
    }

    _initialized = true;
    notifyListeners();
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

      _user = user;

      if (user != null) {
        await _loadUserProfile(user.uid);
      }
    } finally {
      _setLoading(false);
    }
  }

  // ===================================================
  // LOGOUT
  // ===================================================
  Future<void> logout() async {
    await AuthService.instance.logout();

    _user = null;
    _role = null;
    _departmentId = null;
    _teacherApproved = false;
    _teacherSetupCompleted = false;

    notifyListeners();
  }

  // ===================================================
  // LOAD USER PROFILE (TYPE SAFE)
  // ===================================================
  Future<void> _loadUserProfile(String uid) async {
    // -------- users collection --------
    final userData = await FirestoreService.instance.getUserData(uid);

    if (userData == null) return;

    _role = userData['role'] as String?;

    // -------- teacher --------
    if (_role == 'teacher') {
      final teacherData = await FirestoreService.instance.getTeacher(uid);

      if (teacherData != null) {
        _departmentId = teacherData['departmentId'];
        _teacherApproved = teacherData['isApproved'] ?? false;
        _teacherSetupCompleted = teacherData['setupCompleted'] ?? false;
      }
    }

    // -------- student --------
    if (_role == 'student') {
      final studentData = await FirestoreService.instance.getStudent(uid);

      if (studentData != null) {
        _departmentId = studentData['departmentId'];
      }
    }

    notifyListeners();
  }

  // ===================================================
  // HELPER
  // ===================================================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

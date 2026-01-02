import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:darzo/auth/auth_service.dart';
import 'package:darzo/services/firestore_service.dart';

class AppAuthProvider extends ChangeNotifier {
  // ===================================================
  // STATE
  // ===================================================
  User? _user;

  String? _role;
  String? _departmentId;
  String? _name;

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
  String? get name => _name;

  bool get isLoggedIn => _user != null;
  bool get isAdmin => _role == 'admin';
  bool get isStudent => _role == 'student';
  bool get isTeacher => _role == 'teacher';

  bool get isTeacherApproved => _teacherApproved;
  bool get isTeacherSetupCompleted => _teacherSetupCompleted;

  bool get isInitialized => _initialized;
  bool get isLoading => _isLoading;

  // ===================================================
  // INIT (AUTO LOGIN)
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

      if (user == null) {
        throw Exception("Authentication failed");
      }

      _user = user;
      await _loadUserProfile(user.uid);
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
    _name = null;
    _teacherApproved = false;
    _teacherSetupCompleted = false;

    notifyListeners();
  }

  // ===================================================
  // LOAD USER PROFILE (ROLE → PROFILE)
  // ===================================================
  Future<void> _loadUserProfile(String uid) async {
    // ---------- USERS (ROLE SOURCE OF TRUTH) ----------
    final userData = await FirestoreService.instance.getUser(uid);

    if (userData == null) {
      throw Exception("User document missing");
    }

    _role = userData['role'];

    // ---------- ADMIN ----------
    if (_role == 'admin') {
      _name = userData['name']; // optional
      notifyListeners();
      return;
    }

    // ---------- STUDENT ----------
    if (_role == 'student') {
      final studentData = await FirestoreService.instance.getStudent(uid);

      if (studentData == null) {
        throw Exception("Student profile missing");
      }

      _departmentId = studentData['departmentId'];
      _name = studentData['name'];

      notifyListeners();
      return;
    }

    // ---------- TEACHER ----------
    if (_role == 'teacher') {
      final teacherData = await FirestoreService.instance.getTeacher(uid);

      if (teacherData == null) {
        throw Exception("Teacher profile missing");
      }

      _teacherApproved = teacherData['isApproved'] ?? false;
      _teacherSetupCompleted = teacherData['setupCompleted'] ?? false;
      _departmentId = teacherData['departmentId'];
      _name = teacherData['name'];

      if (!_teacherApproved) {
        throw Exception("Teacher not approved by admin");
      }

      notifyListeners();
      return;
    }

    throw Exception("Invalid user role");
  }

  // ===================================================
  // HELPER
  // ===================================================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

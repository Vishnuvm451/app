import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // =====================================================
  // CURRENT USER
  // =====================================================
  User? get currentUser => _auth.currentUser;

  // =====================================================
  // LOGIN (STUDENT / TEACHER / ADMIN)
  // =====================================================
  Future<User?> login({required String email, required String password}) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  // =====================================================
  // LOGOUT
  // =====================================================
  Future<void> logout() async {
    await _auth.signOut();
  }

  // =====================================================
  // STUDENT AUTH REGISTRATION
  // =====================================================
  /// Creates Firebase Auth user only.
  /// Firestore data must be created separately.
  Future<User?> registerStudent({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  // =====================================================
  // TEACHER AUTH CREATION (ADMIN APPROVAL FLOW)
  // =====================================================
  /// Used ONLY by Admin during approval.
  Future<User?> createTeacherAuth({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user;
  }

  // =====================================================
  // PASSWORD RESET
  // =====================================================
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // =====================================================
  // AUTH STATE STREAM (OPTIONAL, FOR AUTO LOGIN)
  // =====================================================
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}

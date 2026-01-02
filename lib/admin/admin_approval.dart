import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class TeacherApprovalPage extends StatelessWidget {
  const TeacherApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Approvals"), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teacher_request')
            .where('status', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No pending teacher requests",
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final bool emailVerified = data['emailVerified'] == true;

              final String deptName =
                  data['departmentName'] ?? data['departmentId'] ?? '-';

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---------- NAME ----------
                      Text(
                        data['name'] ?? 'No Name',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // ---------- EMAIL ----------
                      Text(data['email'] ?? ''),

                      const SizedBox(height: 6),

                      // ---------- DEPARTMENT ----------
                      Text(
                        "Department: $deptName",
                        style: const TextStyle(color: Colors.grey),
                      ),

                      const SizedBox(height: 6),

                      // ---------- EMAIL VERIFIED STATUS ----------
                      Row(
                        children: [
                          Icon(
                            emailVerified
                                ? Icons.verified
                                : Icons.warning_amber_rounded,
                            color: emailVerified ? Colors.green : Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            emailVerified
                                ? "Email Verified"
                                : "Email NOT Verified",
                            style: TextStyle(
                              color: emailVerified
                                  ? Colors.green
                                  : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ---------- ACTION BUTTONS ----------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                            onPressed: () => _approveTeacher(
                              context: context,
                              requestId: doc.id,
                              requestData: data,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _rejectTeacher(
                              context: context,
                              requestId: doc.id,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ==================================================
  // APPROVE TEACHER (ADMIN)
  // ==================================================
  Future<void> _approveTeacher({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    FirebaseApp? tempApp;

    try {
      final db = FirebaseFirestore.instance;

      final reqSnap = await db
          .collection('teacher_request')
          .doc(requestId)
          .get();

      if (!reqSnap.exists || reqSnap['status'] != 'pending') {
        _showSnack(context, "Request already processed");
        return;
      }

      tempApp = await Firebase.initializeApp(
        name: 'TempTeacherCreate',
        options: Firebase.app().options,
      );

      final auth = FirebaseAuth.instanceFor(app: tempApp);

      final cred = await auth.createUserWithEmailAndPassword(
        email: requestData['email'],
        password: requestData['password'],
      );

      final uid = cred.user!.uid;

      await db.collection('users').doc(uid).set({
        'uid': uid,
        'name': requestData['name'],
        'email': requestData['email'],
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await db.collection('teacher').doc(uid).set({
        'uid': uid,
        'name': requestData['name'],
        'email': requestData['email'],
        'departmentId': requestData['departmentId'],
        'isApproved': true,
        'setupCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await db.collection('teacher_request').doc(requestId).update({
        'status': 'approved',
        'authUid': uid,
        'approvedAt': FieldValue.serverTimestamp(),
        'password': FieldValue.delete(),
      });

      _showSnack(
        context,
        "Teacher approved successfully. The teacher can now log in.",
        success: true,
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Approval failed";

      if (e.code == 'email-already-in-use') {
        msg = "This email is already registered";
      }

      _showSnack(context, msg);
    } catch (_) {
      _showSnack(context, "Unexpected error during approval");
    } finally {
      await tempApp?.delete();
    }
  }

  // ==================================================
  // REJECT TEACHER
  // ==================================================
  Future<void> _rejectTeacher({
    required BuildContext context,
    required String requestId,
  }) async {
    await FirebaseFirestore.instance
        .collection('teacher_request')
        .doc(requestId)
        .update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });

    _showSnack(context, "Teacher request rejected", success: true);
  }

  // ==================================================
  // SNACKBAR
  // ==================================================
  void _showSnack(BuildContext context, String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

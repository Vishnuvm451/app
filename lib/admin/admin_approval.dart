import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class TeacherApprovalPage extends StatelessWidget {
  const TeacherApprovalPage({super.key});

  final Color primaryBlue = const Color(0xFF2196F3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text("Teacher Approvals"),
        centerTitle: true,
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
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
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No pending requests",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildRequestCard(context, doc.id, data);
            },
          );
        },
      ),
    );
  }

  // ==================================================
  // CARD (UI UNCHANGED)
  // ==================================================
  Widget _buildRequestCard(
    BuildContext context,
    String requestId,
    Map<String, dynamic> data,
  ) {
    final bool emailVerified = data['emailVerified'] == true;

    final String name = data['name'] ?? 'No Name';
    final String email = data['email'] ?? '';
    final String dept = data['departmentName'] ?? data['departmentId'] ?? '-';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.orange.shade400, width: 6),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // INFO
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: primaryBlue.withOpacity(0.1),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "Dept: $dept",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                emailVerified
                                    ? Icons.verified
                                    : Icons.warning_amber_rounded,
                                size: 16,
                                color: emailVerified
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                emailVerified
                                    ? "Email Verified"
                                    : "Email Not Verified",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: emailVerified
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _rejectTeacher(
                          context: context,
                          requestId: requestId,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.shade200),
                        ),
                        child: const Text("Reject"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _approveTeacher(
                          context: context,
                          requestId: requestId,
                          requestData: data,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryBlue,
                        ),
                        child: const Text("Approve"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================================================
  // APPROVE (LOGIC FIXED)
  // ==================================================
  Future<void> _approveTeacher({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    // ❗ BLOCK approval if email not verified
    if (requestData['emailVerified'] != true) {
      _showSnack(context, "Teacher email is not verified yet");
      return;
    }

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
        'departmentName': requestData['departmentName'],
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

      _showSnack(context, "Teacher approved successfully", success: true);
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

  void _showSnack(BuildContext context, String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

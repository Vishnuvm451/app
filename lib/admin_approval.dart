import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class TeacherApprovalPage extends StatelessWidget {
  const TeacherApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Approvals")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('teacher_requests')
            .where('status', isEqualTo: 'pending')
            .orderBy('created_at')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No pending teacher requests"));
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 3,
                child: ListTile(
                  title: Text(
                    data['name'] ?? 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['email']),
                      const SizedBox(height: 4),
                      Text(
                        "Department: ${data['departmentId']}",
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
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
                        onPressed: () =>
                            _rejectTeacher(context: context, requestId: doc.id),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // APPROVE TEACHER
  // --------------------------------------------------
  Future<void> _approveTeacher({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    FirebaseApp? tempApp;

    try {
      // 🔐 TEMP APP (ADMIN SHOULD NOT LOGOUT)
      tempApp = await Firebase.initializeApp(
        name: 'TempTeacherCreate',
        options: Firebase.app().options,
      );

      // 1️⃣ CREATE AUTH USER
      final cred = await FirebaseAuth.instanceFor(app: tempApp)
          .createUserWithEmailAndPassword(
            email: requestData['email'],
            password: 'teacher@123', // temp password
          );

      final uid = cred.user!.uid;

      // 2️⃣ CREATE USERS DOC
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'name': requestData['name'],
        'email': requestData['email'],
        'role': 'teacher',
        'created_at': FieldValue.serverTimestamp(),
      });

      // 3️⃣ CREATE TEACHER DOC
      await FirebaseFirestore.instance.collection('teachers').doc(uid).set({
        'uid': uid,
        'name': requestData['name'],
        'email': requestData['email'],
        'departmentId': requestData['departmentId'],
        'setupCompleted': false,
        'created_at': FieldValue.serverTimestamp(),
      });

      // 4️⃣ UPDATE REQUEST STATUS
      await FirebaseFirestore.instance
          .collection('teacher_requests')
          .doc(requestId)
          .update({
            'status': 'approved',
            'authUid': uid,
            'approved_at': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Teacher approved. Login credentials created."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Approval failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      await tempApp?.delete();
    }
  }

  // --------------------------------------------------
  // REJECT TEACHER
  // --------------------------------------------------
  Future<void> _rejectTeacher({
    required BuildContext context,
    required String requestId,
  }) async {
    await FirebaseFirestore.instance
        .collection('teacher_requests')
        .doc(requestId)
        .update({
          'status': 'rejected',
          'rejected_at': FieldValue.serverTimestamp(),
        });

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Teacher request rejected")));
    }
  }
}

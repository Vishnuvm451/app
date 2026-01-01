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
            .collection('teacher_requests')
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

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    data['name'] ?? 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['email'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        "Department: ${data['departmentId'] ?? '-'}",
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
            },
          );
        },
      ),
    );
  }

  // --------------------------------------------------
  // APPROVE TEACHER (ADMIN ONLY)
  // --------------------------------------------------
  Future<void> _approveTeacher({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> requestData,
  }) async {
    FirebaseApp? tempApp;

    try {
      final db = FirebaseFirestore.instance;

      // 🔒 Safety check (already approved?)
      final reqSnap = await db
          .collection('teacher_requests')
          .doc(requestId)
          .get();
      if (!reqSnap.exists || reqSnap['status'] != 'pending') {
        return;
      }

      // 🔐 Create secondary Firebase app
      tempApp = await Firebase.initializeApp(
        name: 'TempTeacherCreate',
        options: Firebase.app().options,
      );

      final auth = FirebaseAuth.instanceFor(app: tempApp);

      // 1️⃣ CREATE AUTH USER (TEMP PASSWORD)
      final cred = await auth.createUserWithEmailAndPassword(
        email: requestData['email'],
        password: 'Temp@12345', // temporary
      );

      final uid = cred.user!.uid;

      // 2️⃣ USERS COLLECTION
      await db.collection('users').doc(uid).set({
        'uid': uid,
        'name': requestData['name'],
        'email': requestData['email'],
        'role': 'teacher',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3️⃣ TEACHERS COLLECTION (CORRECT COLLECTION NAME)
      await db.collection('teachers').doc(uid).set({
        'uid': uid,
        'name': requestData['name'],
        'email': requestData['email'],
        'departmentId': requestData['departmentId'],
        'isApproved': true,
        'setupCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4️⃣ UPDATE REQUEST STATUS
      await db.collection('teacher_requests').doc(requestId).update({
        'status': 'approved',
        'authUid': uid,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Teacher approved successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Approval failed"),
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
          'rejectedAt': FieldValue.serverTimestamp(),
        });

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Teacher request rejected")));
    }
  }
}

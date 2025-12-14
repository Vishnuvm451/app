import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TeacherApprovalPage extends StatelessWidget {
  const TeacherApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Approvals")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("teacher_requests")
            .where("status", isEqualTo: "pending")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No pending requests"));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text(data['name']),
                  subtitle: Text("${data['email']}\n${data['department']}"),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // APPROVE BUTTON
                      IconButton(
                        icon: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        tooltip: "Approve",
                        onPressed: () async {
                          await _approveTeacher(
                            context: context,
                            requestId: doc.id,
                            data: data,
                          );
                        },
                      ),

                      // DENY BUTTON
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        tooltip: "Deny",
                        onPressed: () async {
                          await _denyTeacher(
                            context: context,
                            requestId: doc.id,
                          );
                        },
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
  // DENY TEACHER REQUEST
  // --------------------------------------------------
  Future<void> _denyTeacher({
    required BuildContext context,
    required String requestId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection("teacher_requests")
          .doc(requestId)
          .update({
            "status": "rejected",
            "rejected_at": FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Teacher request rejected")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --------------------------------------------------
  // APPROVE TEACHER
  // --------------------------------------------------
  Future<void> _approveTeacher({
    required BuildContext context,
    required String requestId,
    required Map<String, dynamic> data,
  }) async {
    try {
      // 1️⃣ Create Firebase Auth user
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: data['email'],
            password: "teacher@123", // TEMP password
          );

      final uid = cred.user!.uid;

      // 2️⃣ Create Firestore user profile
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "uid": uid,
        "name": data['name'],
        "email": data['email'],
        "role": "teacher",
        "created_at": FieldValue.serverTimestamp(),
      });

      // 3️⃣ Create teacher profile
      await FirebaseFirestore.instance.collection("teachers").doc(uid).set({
        "uid": uid,
        "name": data['name'],
        "email": data['email'],
        "department": data['department'],
        "created_at": FieldValue.serverTimestamp(),
      });

      // 4️⃣ Update request status
      await FirebaseFirestore.instance
          .collection("teacher_requests")
          .doc(requestId)
          .update({"status": "approved"});

      // 5️⃣ Success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Teacher approved successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}

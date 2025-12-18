// import 'package:firebase_core/firebase_core.dart'; // Required for the Admin fix
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class TeacherApprovalPage extends StatelessWidget {
//   const TeacherApprovalPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Teacher Approvals")),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection("teacher_requests")
//             .where("status", isEqualTo: "pending")
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//             return const Center(child: Text("No pending requests"));
//           }

//           return ListView(
//             children: snapshot.data!.docs.map((doc) {
//               final data = doc.data() as Map<String, dynamic>;

//               // Handle both new and old data structures for display
//               final deptName =
//                   data['departmentName'] ??
//                   data['department'] ??
//                   'Unknown Dept';

//               return Card(
//                 margin: const EdgeInsets.all(12),
//                 child: ListTile(
//                   title: Text(data['name'] ?? "No Name"),
//                   subtitle: Text("${data['email']}\n$deptName"),
//                   isThreeLine: true,
//                   trailing: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       // APPROVE BUTTON
//                       IconButton(
//                         icon: const Icon(
//                           Icons.check_circle,
//                           color: Colors.green,
//                         ),
//                         tooltip: "Approve",
//                         onPressed: () async {
//                           await _approveTeacher(
//                             context: context,
//                             requestId: doc.id,
//                             data: data,
//                           );
//                         },
//                       ),

//                       // DENY BUTTON
//                       IconButton(
//                         icon: const Icon(Icons.cancel, color: Colors.red),
//                         tooltip: "Deny",
//                         onPressed: () async {
//                           await _denyTeacher(
//                             context: context,
//                             requestId: doc.id,
//                           );
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             }).toList(),
//           );
//         },
//       ),
//     );
//   }

//   // DENY TEACHER REQUEST
//   Future<void> _denyTeacher({
//     required BuildContext context,
//     required String requestId,
//   }) async {
//     try {
//       await FirebaseFirestore.instance
//           .collection("teacher_requests")
//           .doc(requestId)
//           .update({
//             "status": "rejected",
//             "rejected_at": FieldValue.serverTimestamp(),
//           });

//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("Teacher request rejected")),
//         );
//       }
//     } catch (e) {
//       if (context.mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("Error: $e")));
//       }
//     }
//   }

//   // --------------------------------------------------
//   // APPROVE TEACHER
//   // --------------------------------------------------
//   Future<void> _approveTeacher({
//     required BuildContext context,
//     required String requestId,
//     required Map<String, dynamic> data,
//   }) async {
//     // We use a secondary app instance to prevent Admin logout
//     FirebaseApp? tempApp;

//     try {
//       // 0️⃣ INITIALIZE TEMP APP
//       tempApp = await Firebase.initializeApp(
//         name: 'TemporaryRegisterApp',
//         options: Firebase.app().options,
//       );

//       // 1️⃣ CREATE AUTH USER (Using the teacher's password from registration)
//       UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp)
//           .createUserWithEmailAndPassword(
//             email: data['email'],
//             // Use the password they typed during registration, or fallback to default
//             password: data['password'] ?? "teacher@123",
//           );

//       final String uid = cred.user!.uid;

//       // 2️⃣ CREATE users/{uid}
//       await FirebaseFirestore.instance.collection("users").doc(uid).set({
//         "uid": uid,
//         "name": data['name'],
//         "email": data['email'],
//         "role": "teacher",
//         "created_at": FieldValue.serverTimestamp(),
//         "profile_completed": false, // Important for routing logic
//       });

//       // 3️⃣ CREATE teachers/{uid}
//       // 🔥 UPDATED: Saving departmentId and departmentName correctly
//       await FirebaseFirestore.instance.collection("teachers").doc(uid).set({
//         "uid": uid,
//         "name": data['name'],
//         "email": data['email'],

//         // Unified Structure
//         "departmentId": data['departmentId'],
//         "departmentName": data['departmentName'] ?? data['department'],

//         "setupCompleted": false,
//         "created_at": FieldValue.serverTimestamp(),
//       });

//       // 4️⃣ UPDATE teacher_requests STATUS
//       await FirebaseFirestore.instance
//           .collection("teacher_requests")
//           .doc(requestId)
//           .update({
//             "status": "approved",
//             "approved_at": FieldValue.serverTimestamp(),
//             "auth_uid": uid,
//           });

//       // 5️⃣ SUCCESS MESSAGE
//       if (context.mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//               "Teacher approved successfully.\nLogin credentials created.",
//             ),
//           ),
//         );
//       }
//     } on FirebaseAuthException catch (e) {
//       if (context.mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("Auth error: ${e.message}")));
//       }
//     } catch (e) {
//       if (context.mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("Error: $e")));
//       }
//     } finally {
//       // 6️⃣ CLEANUP TEMP APP
//       await tempApp?.delete();
//     }
//   }
// }

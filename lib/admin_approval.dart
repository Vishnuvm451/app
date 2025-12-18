import 'package:darzo/new/auth_provider.dart';
import 'package:darzo/new/auth_service.dart';
import 'package:darzo/new/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AdminTeacherApprovalPage extends StatelessWidget {
  const AdminTeacherApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Safety: only admin can access
    if (!auth.isAdmin) {
      return const Scaffold(body: Center(child: Text("Unauthorized")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Teacher Approvals")),
      body: StreamBuilder(
        stream: FirestoreService.instance.teacherRequestsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No pending requests"));
          }

          final requests = snapshot.data!;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];

              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text(req['name']),
                  subtitle: Text(
                    "${req['email']}\nDepartment: ${req['departmentName'] ?? req['departmentId']}",
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _approve(context, req),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _reject(context, req['requestId']),
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
  // APPROVE TEACHER
  // --------------------------------------------------
  Future<void> _approve(BuildContext context, Map<String, dynamic> req) async {
    try {
      // 1. Create Auth user
      final user = await AuthService.instance.createTeacherAuth(
        email: req['email'],
        password: req['password'],
      );

      if (user == null) throw "Auth creation failed";

      final uid = user.uid;

      // 2. Create Firestore records
      await FirestoreService.instance.approveTeacher(
        requestId: req['requestId'],
        uid: uid,
        name: req['name'],
        email: req['email'],
        departmentId: req['departmentId'],
      );

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Teacher approved")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --------------------------------------------------
  // REJECT TEACHER
  // --------------------------------------------------
  Future<void> _reject(BuildContext context, String requestId) async {
    try {
      await FirestoreService.instance.rejectTeacher(requestId);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Teacher rejected")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
}

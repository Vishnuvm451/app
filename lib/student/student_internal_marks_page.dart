import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentInternalMarksPage extends StatefulWidget {
  const StudentInternalMarksPage({super.key});

  @override
  State<StudentInternalMarksPage> createState() =>
      _StudentInternalMarksPageState();
}

class _StudentInternalMarksPageState extends State<StudentInternalMarksPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  String classId = '';
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudentClass();
  }

  // --------------------------------------------------
  // LOAD STUDENT CLASS
  // --------------------------------------------------
  Future<void> _loadStudentClass() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }

      final q = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        throw Exception("Student profile not found");
      }

      final studentDoc = q.docs.first;
      final data = studentDoc.data();

      // ✅ Load classId
      classId = data['classId'] ?? '';

      if (classId.isEmpty) {
        throw Exception("Class ID not found in student profile");
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error loading student class: $e");
      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    }
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Internal Marks"), centerTitle: true),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 60,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              isLoading = true;
                              errorMessage = null;
                            });
                            _loadStudentClass();
                          },
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : _marksList(),
    );
  }

  // --------------------------------------------------
  // INTERNAL MARKS LIST
  // --------------------------------------------------
  Widget _marksList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('internal_mark')
          .where('classId', isEqualTo: classId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  "Error: ${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  "No internal marks published yet",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final tests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tests.length,
          itemBuilder: (_, index) {
            final test = tests[index];
            final testData = test.data() as Map<String, dynamic>;

            return FutureBuilder<DocumentSnapshot>(
              future: test.reference.collection('student').doc(uid).get(),
              builder: (_, stuSnap) {
                if (!stuSnap.hasData) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(
                        testData['testName'] ?? 'Unnamed Test',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text("Subject ID: ${testData['subjectId'] ?? 'N/A'}"),
                      trailing: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                if (!stuSnap.data!.exists) {
                  // Student not marked for this test
                  return const SizedBox();
                }

                final studentData = stuSnap.data!.data() as Map<String, dynamic>;
                final marks = studentData['marks'] ?? 0;
                final total = testData['totalMarks'] ?? 0;

                // Calculate percentage
                final percentage = total > 0 ? (marks / total * 100) : 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      testData['testName'] ?? 'Unnamed Test',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text("Subject ID: ${testData['subjectId'] ?? 'N/A'}"),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "$marks / $total",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${percentage.toStringAsFixed(1)}%",
                          style: TextStyle(
                            fontSize: 14,
                            color: percentage >= 50 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
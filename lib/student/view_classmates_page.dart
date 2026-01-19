import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ViewClassmatesPage extends StatefulWidget {
  const ViewClassmatesPage({super.key});

  @override
  State<ViewClassmatesPage> createState() => _ViewClassmatesPageState();
}

class _ViewClassmatesPageState extends State<ViewClassmatesPage> {
  bool isLoading = true;
  String? errorMessage;
  String? myClassId;
  List<Map<String, dynamic>> classmates = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not logged in";

      // 1. Get My Profile to find my Class ID
      final myProfileSnap = await FirebaseFirestore.instance
          .collection('student')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (myProfileSnap.docs.isEmpty) throw "Student profile not found";

      final myData = myProfileSnap.docs.first.data();
      myClassId = myData['classId'];

      if (myClassId == null) throw "Class ID missing in profile";

      // 2. Fetch All Students in SAME Class
      // 🚀 SIMPLIFIED: Removed 'orderBy' to fix Index Error
      final querySnapshot = await FirebaseFirestore.instance
          .collection('student')
          .where('classId', isEqualTo: myClassId)
          .get();

      // 3. Process & Sort Data in App (Avoids Firebase Index requirement)
      List<Map<String, dynamic>> tempList = querySnapshot.docs
          .map((doc) => doc.data())
          .toList();

      // Sort by Admission Number locally
      tempList.sort((a, b) {
        final adNoA = (a['admissionNo'] ?? '').toString();
        final adNoB = (b['admissionNo'] ?? '').toString();
        return adNoA.compareTo(adNoB);
      });

      if (mounted) {
        setState(() {
          classmates = tempList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("My Classmates"),
        centerTitle: true,
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? Center(child: Text("Error: $errorMessage"))
          : Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF2196F3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Class ID: ${myClassId ?? '...'}",
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        "${classmates.length} Students Found",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: classmates.length,
                    itemBuilder: (context, index) {
                      final student = classmates[index];
                      final name = student['name'] ?? 'Unknown';
                      final admissionNo = student['admissionNo'] ?? '-';

                      // Highlight "Me"
                      final isMe =
                          student['authUid'] ==
                          FirebaseAuth.instance.currentUser?.uid;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isMe
                              ? const BorderSide(color: Colors.blue, width: 2)
                              : BorderSide.none,
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isMe
                                ? Colors.blue
                                : Colors.blue.shade100,
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : Colors.blue.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text("Adm No: $admissionNo"),
                          trailing: isMe
                              ? const Chip(
                                  label: Text("You"),
                                  backgroundColor: Colors.blueAccent,
                                  labelStyle: TextStyle(color: Colors.white),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

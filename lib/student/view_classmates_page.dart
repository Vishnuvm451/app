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
  String myClassName = "Loading..."; // Default safe value
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
      myClassId = myData['classId']?.toString(); // Force to String

      if (myClassId == null || myClassId!.isEmpty)
        throw "Class ID missing in profile";

      // 2. Fetch Class Name (Crash-Proof Logic)
      String tempClassName = myClassId!;
      try {
        final classDoc = await FirebaseFirestore.instance
            .collection('class')
            .doc(myClassId)
            .get();

        if (classDoc.exists && classDoc.data() != null) {
          final data = classDoc.data()!;
          // Explicitly check fields and convert to String to avoid Type errors
          if (data['name'] != null) {
            tempClassName = data['name'].toString();
          } else if (data['className'] != null) {
            tempClassName = data['className'].toString();
          } else if (data['deptName'] != null) {
            tempClassName = data['deptName'].toString();
          }
        }
      } catch (e) {
        debugPrint("Error fetching class name: $e");
      }

      // 3. Fetch All Students in SAME Class
      final querySnapshot = await FirebaseFirestore.instance
          .collection('student')
          .where('classId', isEqualTo: myClassId)
          .get();

      // 4. Process & Sort Data
      List<Map<String, dynamic>> tempList = querySnapshot.docs
          .map((doc) => doc.data())
          .toList();

      // Sort by Admission Number (Safely)
      tempList.sort((a, b) {
        final adNoA = (a['admissionNo'] ?? '').toString();
        final adNoB = (b['admissionNo'] ?? '').toString();
        return adNoA.compareTo(adNoB);
      });

      if (mounted) {
        setState(() {
          myClassName = tempClassName;
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
                        "Class: $myClassName",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
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

                      // ✅ FORCE TO STRING to prevent "Null is not subtype of String" error
                      final name = (student['name'] ?? 'Unknown').toString();
                      final admissionNo = (student['admissionNo'] ?? '-')
                          .toString();

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

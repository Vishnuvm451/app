import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InternalMarksPage extends StatefulWidget {
  const InternalMarksPage({super.key});

  @override
  State<InternalMarksPage> createState() => _InternalMarksPageState();
}

class _InternalMarksPageState extends State<InternalMarksPage> {
  // --------------------------------------------------
  // STATE VARIABLES
  // --------------------------------------------------
  String? teacherDeptId;
  DocumentSnapshot? selectedClassDoc; // Store full doc for ID & Name
  DocumentSnapshot? selectedSubjectDoc; // Store full doc for ID & Name
  String? selectedInternal;

  final List<String> internals = ["Internal 1", "Internal 2", "Model Exam"];
  final int maxMarks = 50;

  // Stores marks locally before saving: { "studentUid": "45" }
  final Map<String, String> marksMap = {};

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTeacherDept();
  }

  // 1. Get Teacher's Department to filter classes
  Future<void> _fetchTeacherDept() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('teachers')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          teacherDeptId = doc.data()?['departmentId'];
        });
      }
    }
  }

  // --------------------------------------------------
  // SAVE TO FIRESTORE
  // --------------------------------------------------
  Future<void> _saveMarks(List<QueryDocumentSnapshot> students) async {
    if (marksMap.isEmpty) return;

    setState(() => isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (var student in students) {
        final studentId = student.id;
        final markValue = marksMap[studentId];

        // Skip empty or invalid marks
        if (markValue == null || markValue.isEmpty) continue;

        final markInt = int.tryParse(markValue);
        if (markInt == null || markInt > maxMarks) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Invalid marks for ${student['name']}")),
          );
          setState(() => isLoading = false);
          return;
        }

        // Create a unique ID for the mark entry
        // Format: classId_subjectId_examName_studentId
        final docId =
            "${selectedClassDoc!.id}_${selectedSubjectDoc!.id}_${selectedInternal}_$studentId";

        final docRef = FirebaseFirestore.instance
            .collection('internals')
            .doc(docId);

        batch.set(docRef, {
          "studentId": studentId,
          "studentName": student['name'],
          "register_number": student['register_number'],

          "classId": selectedClassDoc!.id,
          "className": selectedClassDoc!['name'],

          "subjectId": selectedSubjectDoc!.id,
          "subjectName": selectedSubjectDoc!['name'],

          "examName": selectedInternal,
          "marks": markInt,
          "maxMarks": maxMarks,
          "date": FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Marks saved successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --------------------------------------------------
  // UI
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Internal Marks"),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: teacherDeptId == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ================= CLASS DROPDOWN =================
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('classes')
                        .where('departmentId', isEqualTo: teacherDeptId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const LinearProgressIndicator();

                      return _buildDropdown(
                        label: "Select Class",
                        value: selectedClassDoc,
                        items: snapshot.data!.docs,
                        onChanged: (val) {
                          setState(() {
                            selectedClassDoc = val as DocumentSnapshot?;
                            selectedSubjectDoc = null; // Reset dependants
                            selectedInternal = null;
                            marksMap.clear();
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // ================= SUBJECT DROPDOWN =================
                  if (selectedClassDoc != null)
                    StreamBuilder<QuerySnapshot>(
                      // Fetch subjects linked to this class OR generic department subjects
                      // Simplified: Fetch subjects for this department
                      stream: FirebaseFirestore.instance
                          .collection('subjects')
                          .where('departmentId', isEqualTo: teacherDeptId)
                          // You might want to filter by 'semester' or 'classId' if your schema supports it
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox();

                        return _buildDropdown(
                          label: "Select Subject",
                          value: selectedSubjectDoc,
                          items: snapshot.data!.docs,
                          onChanged: (val) {
                            setState(() {
                              selectedSubjectDoc = val as DocumentSnapshot?;
                              selectedInternal = null;
                              marksMap.clear();
                            });
                          },
                        );
                      },
                    ),

                  const SizedBox(height: 12),

                  // ================= INTERNAL DROPDOWN =================
                  DropdownButtonFormField<String>(
                    value: selectedInternal,
                    decoration: InputDecoration(
                      labelText: "Select Exam",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    items: internals
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: selectedSubjectDoc == null
                        ? null
                        : (val) => setState(() => selectedInternal = val),
                  ),

                  const SizedBox(height: 20),

                  // ================= STUDENT LIST & INPUTS =================
                  if (selectedClassDoc != null &&
                      selectedSubjectDoc != null &&
                      selectedInternal != null)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('students')
                          .where('classId', isEqualTo: selectedClassDoc!.id)
                          .orderBy('name')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Text("No students found in this class.");
                        }

                        final students = snapshot.data!.docs;

                        return Column(
                          children: [
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: students.length,
                              itemBuilder: (context, index) {
                                final student = students[index];
                                final data =
                                    student.data() as Map<String, dynamic>;

                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Reg No
                                        SizedBox(
                                          width: 60,
                                          child: Text(
                                            data['register_number'] ?? "---",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),

                                        // Name
                                        Expanded(
                                          child: Text(
                                            data['name'] ?? "Unknown",
                                          ),
                                        ),

                                        // Marks Input
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: "/$maxMarks",
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 0,
                                                  ),
                                            ),
                                            onChanged: (value) {
                                              marksMap[student.id] = value;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 20),

                            // SAVE BUTTON
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () => _saveMarks(students),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade800,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  foregroundColor: Colors.white,
                                ),
                                child: isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text(
                                        "SAVE MARKS",
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required DocumentSnapshot? value,
    required List<QueryDocumentSnapshot> items,
    required Function(Object?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<DocumentSnapshot>(
          value: value,
          isExpanded: true,
          items: items.map((doc) {
            return DropdownMenuItem(
              value: doc,
              child: Text(doc['name']), // Assuming 'name' field exists on docs
            );
          }).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}

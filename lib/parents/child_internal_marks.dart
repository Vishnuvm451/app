import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ParentInternalMarksPage extends StatefulWidget {
  final String admissionNo;

  const ParentInternalMarksPage({
    super.key,
    required this.admissionNo,
    required studentName,
  });

  @override
  State<ParentInternalMarksPage> createState() =>
      _ParentInternalMarksPageState();
}

class _ParentInternalMarksPageState extends State<ParentInternalMarksPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Theme Colors
  final Color primaryBlue = const Color(0xFF1565C0);
  final Color bgLight = const Color(0xFFF5F7FA);
  final Color textDark = const Color(0xFF263238);
  final Color textGrey = const Color(0xFF78909C);

  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> _marksList = [];

  @override
  void initState() {
    super.initState();
    _fetchMarks();
  }

  Future<void> _fetchMarks() async {
    try {
      // 1. Get Student Doc ID & Class ID
      // We query by admissionNo to be safe, just in case the Doc ID isn't the admissionNo
      final studentQuery = await _db
          .collection('student')
          .where('admissionNo', isEqualTo: widget.admissionNo)
          .limit(1)
          .get();

      if (studentQuery.docs.isEmpty) {
        // Fallback: Try using admissionNo directly as ID
        final directDoc = await _db
            .collection('student')
            .doc(widget.admissionNo)
            .get();
        if (!directDoc.exists) throw "Student profile not found";
        _processStudentData(directDoc);
      } else {
        _processStudentData(studentQuery.docs.first);
      }
    } catch (e) {
      debugPrint("❌ Error fetching marks: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Could not load marks";
        });
      }
    }
  }

  Future<void> _processStudentData(DocumentSnapshot studentDoc) async {
    final studentData = studentDoc.data() as Map<String, dynamic>;
    final classId = studentData['classId']?.toString().trim() ?? '';
    final studentDocId =
        studentDoc.id; // ✅ This is the correct ID to use for marks

    if (classId.isEmpty) throw "Class not assigned to student";

    // 2. Get Exams for this Class
    final examsQuery = await _db
        .collection('internal_mark')
        .where('classId', isEqualTo: classId)
        .get();

    if (examsQuery.docs.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    List<Map<String, dynamic>> tempMarks = [];

    // 3. Iterate Exams and Fetch Student Score
    for (var examDoc in examsQuery.docs) {
      final examData = examDoc.data();
      final testName = examData['testName'] ?? 'Unknown Test';
      final subjectId = examData['subjectId'] ?? '';

      // Get Max Marks
      final maxData = examData['maxMarks'] as Map<String, dynamic>? ?? {};
      final maxTotal =
          double.tryParse(maxData['total']?.toString() ?? '100') ?? 100.0;

      // Fetch Subject Name
      String subjectName = 'Subject';
      if (subjectId.isNotEmpty) {
        // Try caching this or fetching parallel if slow, but linear is fine for now
        final subSnap = await _db.collection('subject').doc(subjectId).get();
        if (subSnap.exists) {
          subjectName =
              subSnap.data()?['subjectName'] ??
              subSnap.data()?['name'] ??
              subjectId;
        }
      }

      // 4. Fetch Score using the Student Document ID
      // Path: internal_mark/{examId}/student/{studentDocId}
      final scoreDoc = await examDoc.reference
          .collection('student')
          .doc(studentDocId) // ✅ Using the retrieved Doc ID
          .get();

      if (scoreDoc.exists) {
        final scoreData = scoreDoc.data()!;
        // Handle different field names for score (obtainedMarks, total, internal)
        var obtainedVal =
            scoreData['obtainedMarks'] ??
            scoreData['total'] ??
            scoreData['internal'] ??
            0;
        final obtained = double.tryParse(obtainedVal.toString()) ?? 0.0;

        tempMarks.add({
          'testName': testName,
          'subject': subjectName,
          'score': obtained,
          'total': maxTotal,
          'isMissing': false,
        });
      } else {
        // Mark as missing/absent
        tempMarks.add({
          'testName': testName,
          'subject': subjectName,
          'score': 0.0,
          'total': maxTotal,
          'isMissing': true,
        });
      }
    }

    if (mounted) {
      setState(() {
        _marksList = tempMarks;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        title: const Text(
          "Internal Marks",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : errorMessage != null
          ? Center(
              child: Text(errorMessage!, style: TextStyle(color: textGrey)),
            )
          : _marksList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 60,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text("No marks found", style: TextStyle(color: textGrey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _marksList.length,
              itemBuilder: (context, index) {
                final mark = _marksList[index];
                return _buildMarkCard(mark);
              },
            ),
    );
  }

  Widget _buildMarkCard(Map<String, dynamic> mark) {
    final double score = mark['score'];
    final double total = mark['total'];
    final bool isMissing = mark['isMissing'];
    final double percentage = total == 0 ? 0 : (score / total);

    Color statusColor = Colors.green;
    if (isMissing || percentage < 0.4) {
      statusColor = Colors.red;
    } else if (percentage < 0.75) {
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Badge
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.analytics_rounded, color: primaryBlue),
          ),
          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mark['testName'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  mark['subject'].toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textGrey,
                  ),
                ),
                if (isMissing)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Not Graded / Absent",
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Score Indicator
          if (!isMissing)
            Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 45,
                      height: 45,
                      child: CircularProgressIndicator(
                        value: percentage,
                        backgroundColor: Colors.grey.shade100,
                        color: statusColor,
                        strokeWidth: 5,
                      ),
                    ),
                    Text(
                      "${(percentage * 100).toInt()}%",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "${score.toInt()}/${total.toInt()}",
                  style: TextStyle(
                    fontSize: 12,
                    color: textGrey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

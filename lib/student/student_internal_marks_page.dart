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

  // Theme Colors
  final Color primaryBlue = const Color(0xFF2196F3);
  final Color bgWhite = const Color(0xFFF5F7FA);

  String classId = '';
  String studentDocId = ''; // Admission Number
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStudentProfile();
  }

  // 1. LOAD PROFILE
  Future<void> _loadStudentProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final q = await _db
          .collection('student')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (q.docs.isEmpty) throw Exception("Profile not found");

      final doc = q.docs.first;
      if (mounted) {
        setState(() {
          classId = doc.data()['classId'] ?? '';
          studentDocId = doc.id;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        title: const Text(
          "My Performance",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryBlue))
          : errorMessage != null
          ? _buildErrorState()
          : _buildMarksList(),
    );
  }

  // --------------------------------------------------
  // LIST BUILDER
  // --------------------------------------------------
  Widget _buildMarksList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('internal_mark')
          .where('classId', isEqualTo: classId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryBlue));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final tests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: tests.length,
          itemBuilder: (_, index) {
            final testDoc = tests[index];
            final data = testDoc.data() as Map<String, dynamic>;
            final testName = data['testName'] ?? 'Unknown Test';
            final subjectId = data['subjectId'] ?? 'Unknown Subject';

            // Get Max Marks for percentage calc
            final maxData = data['maxMarks'] as Map<String, dynamic>? ?? {};
            final maxTotal = (maxData['total'] ?? 100).toDouble();

            // Fetch STUDENT result
            return FutureBuilder<DocumentSnapshot>(
              future: testDoc.reference
                  .collection('student')
                  .doc(studentDocId)
                  .get(),
              builder: (_, stuSnap) {
                if (!stuSnap.hasData) return const SizedBox(); // Silent loading

                if (!stuSnap.data!.exists) {
                  return _buildMarkCard(
                    testName: testName,
                    subject: subjectId,
                    score: 0,
                    total: maxTotal,
                    isMissing: true,
                  );
                }

                final scoreData = stuSnap.data!.data() as Map<String, dynamic>;
                final totalScore = (scoreData['total'] ?? 0).toDouble();

                // Detailed breakdown
                final exam = (scoreData['internal'] ?? 0).toDouble();
                final att = (scoreData['attendance'] ?? 0).toDouble();
                final assgn = (scoreData['assignment'] ?? 0).toDouble();

                return _buildMarkCard(
                  testName: testName,
                  subject: subjectId,
                  score: totalScore,
                  total: maxTotal,
                  exam: exam,
                  attendance: att,
                  assignment: assgn,
                );
              },
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------
  // UI COMPONENTS
  // --------------------------------------------------

  Widget _buildMarkCard({
    required String testName,
    required String subject,
    required double score,
    required double total,
    double? exam,
    double? attendance,
    double? assignment,
    bool isMissing = false,
  }) {
    final percentage = total == 0 ? 0.0 : (score / total);

    // Color Logic
    Color statusColor = Colors.green;
    if (isMissing || percentage < 0.4)
      statusColor = Colors.red;
    else if (percentage < 0.75)
      statusColor = Colors.orange;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Icon Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.analytics_rounded, color: primaryBlue),
              ),
              const SizedBox(width: 16),

              // 2. Text Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      testName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Score Ring
              Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          value: isMissing ? 0 : percentage,
                          backgroundColor: Colors.grey.shade100,
                          color: statusColor,
                          strokeWidth: 5,
                        ),
                      ),
                      Text(
                        "${(percentage * 100).toInt()}%",
                        style: TextStyle(
                          fontSize: 12,
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
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 4. Breakdown (Only if not missing)
          if (!isMissing && exam != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSubScore("Exam", exam),
                _buildSubScore("Attend.", attendance ?? 0),
                _buildSubScore("Assgn.", assignment ?? 0),
              ],
            ),
          ],

          if (isMissing)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                "Not Graded Yet",
                style: TextStyle(
                  color: Colors.red.shade400,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubScore(String label, double val) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 2),
        Text(
          val.toStringAsFixed(1), // remove decimal if integer
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "No Marks Published",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Check back later for updates",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red,
            ),
            const SizedBox(height: 20),
            const Text(
              "Something went wrong",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              errorMessage ?? "Unknown Error",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                _loadStudentProfile();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

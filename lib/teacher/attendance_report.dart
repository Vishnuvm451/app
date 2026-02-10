import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart'; // Required for image capture
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TeacherAttendanceReportPage extends StatefulWidget {
  const TeacherAttendanceReportPage({super.key});

  @override
  State<TeacherAttendanceReportPage> createState() =>
      _TeacherAttendanceReportPageState();
}

class _TeacherAttendanceReportPageState
    extends State<TeacherAttendanceReportPage> {
  // --- STATE VARIABLES ---
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ✅ ADDED: GlobalKey to capture the widget as an image
  final GlobalKey _reportKey = GlobalKey();

  // Class Management
  List<Map<String, String>> myClasses = [];
  String? selectedClassId;
  String selectedClassName = "Loading...";

  bool isLoading = true;

  // Student Data
  List<Map<String, dynamic>> students = [];

  // Current Month Stats
  Map<String, double> currentMonthStats = {};

  // Range Calculation State
  DateTime? startDate;
  DateTime? endDate;
  bool isCalculating = false;
  List<Map<String, dynamic>>? rangeReportData;

  @override
  void initState() {
    super.initState();
    _loadTeacherClasses();
  }

  // ---------------------------------------------------------------------------
  // 1. LOAD TEACHER CLASSES
  // ---------------------------------------------------------------------------
  Future<void> _loadTeacherClasses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final teacherDoc = await _db
          .collection('teacher')
          .where('authUid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (teacherDoc.docs.isEmpty) throw "Teacher not found";

      final data = teacherDoc.docs.first.data();
      final ids = data['classIds'] as List?;

      if (ids == null || ids.isEmpty) throw "No class assigned";

      List<Map<String, String>> loadedClasses = [];
      for (var id in ids) {
        final classObj = await _db.collection('class').doc(id).get();
        if (classObj.exists) {
          loadedClasses.add({
            'id': id,
            'name': classObj.data()?['name'] ?? "Unknown Class",
            'className': classObj.data()?['className'] ?? "Class $id",
          });
        }
      }

      if (mounted) {
        setState(() {
          myClasses = loadedClasses;
          if (myClasses.isNotEmpty) {
            _onClassSelected(myClasses.first['id']!);
          } else {
            isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading classes: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 2. LOAD CLASS DATA
  // ---------------------------------------------------------------------------
  Future<void> _onClassSelected(String classId) async {
    setState(() {
      selectedClassId = classId;
      selectedClassName =
          myClasses.firstWhere((e) => e['id'] == classId)['name'] ?? "Class";
      isLoading = true;
      rangeReportData = null;
    });

    try {
      final studentsSnap = await _db
          .collection('student')
          .where('classId', isEqualTo: classId)
          .get();

      students = studentsSnap.docs.map((doc) {
        return {
          'id': doc.id,
          'admissionNo': doc.data()['admissionNo'] ?? doc.id,
          'name': doc.data()['name'] ?? 'Unknown',
        };
      }).toList();

      students.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      final now = DateTime.now();
      final startMonth = DateTime(now.year, now.month, 1);
      final endMonth = DateTime(now.year, now.month + 1, 0);

      await _calculateAttendanceForRange(
        start: startMonth,
        end: endMonth,
        isMainDisplay: true,
      );
    } catch (e) {
      debugPrint("Error loading class data: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 3. CORE CALCULATION LOGIC
  // ---------------------------------------------------------------------------
  Future<void> _calculateAttendanceForRange({
    required DateTime start,
    required DateTime end,
    bool isMainDisplay = false,
  }) async {
    if (selectedClassId == null) return;

    try {
      final query = await _db
          .collection('attendance_final')
          .where('classId', isEqualTo: selectedClassId)
          .get();

      Map<String, double> scores = {};

      List<QueryDocumentSnapshot> validDocs = query.docs.where((doc) {
        final data = doc.data();
        final dateVal = data['date'];
        if (dateVal == null) return false;

        String dateStr = dateVal.toString();
        DateTime? docDate = DateTime.tryParse(dateStr);
        if (docDate == null) return false;

        return docDate.isAfter(start.subtract(const Duration(days: 1))) &&
            docDate.isBefore(end.add(const Duration(days: 1)));
      }).toList();

      int totalWorkingDays = validDocs.length;

      for (var s in students) {
        scores[s['admissionNo']] = 0.0;
      }

      List<Future<QuerySnapshot>> futures = [];
      for (var dayDoc in validDocs) {
        futures.add(dayDoc.reference.collection('student').get());
      }

      final daysResults = await Future.wait(futures);

      for (var daySnap in daysResults) {
        for (var studentLog in daySnap.docs) {
          final data = studentLog.data() as Map<String, dynamic>;

          String admNo = studentLog.id;
          if (data.containsKey('admissionNo')) {
            admNo = data['admissionNo'].toString();
          }

          final status = (data['status'] ?? '').toString().toLowerCase();

          double points = 0.0;
          if (status == 'present')
            points = 1.0;
          else if (status.contains('half'))
            points = 0.5;

          if (scores.containsKey(admNo)) {
            scores[admNo] = (scores[admNo] ?? 0.0) + points;
          }
        }
      }

      if (isMainDisplay) {
        currentMonthStats.clear();
        scores.forEach((adm, score) {
          currentMonthStats[adm] = totalWorkingDays == 0
              ? 0.0
              : (score / totalWorkingDays) * 100;
        });
      } else {
        List<Map<String, dynamic>> results = [];
        for (var s in students) {
          String adm = s['admissionNo'];
          double score = scores[adm] ?? 0.0;
          double pct = totalWorkingDays == 0
              ? 0.0
              : (score / totalWorkingDays) * 100;

          results.add({
            'name': s['name'],
            'admissionNo': adm,
            'percentage': pct,
            'presentDays': score,
            'totalDays': totalWorkingDays,
          });
        }

        results.sort((a, b) => a['name'].compareTo(b['name']));

        if (mounted) {
          setState(() {
            rangeReportData = results;
          });
        }
      }
    } catch (e) {
      debugPrint("Calculation error: $e");
      if (mounted && !isMainDisplay) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ 4. CAPTURE IMAGE AND SHOW PREVIEW
  // ---------------------------------------------------------------------------
  Future<void> _downloadReport() async {
    try {
      // 1. Capture the widget as an image
      RenderRepaintBoundary? boundary =
          _reportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) return;

      // Increase pixelRatio for better quality (3.0 is high res)
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (!mounted) return;

      // 2. Show Image Preview Dialog
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Report Preview",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: SingleChildScrollView(
                        child: Image.memory(pngBytes),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Take a screenshot or use 'Share' (requires package)",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text("Close"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint("Image capture error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error generating image report")),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Student Attendance Report",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CLASS SELECTION
                  if (myClasses.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedClassId,
                          isExpanded: true,
                          hint: const Text("Select Class"),
                          items: myClasses.map((c) {
                            return DropdownMenuItem(
                              value: c['id'],
                              child: Text(
                                c['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) _onClassSelected(val);
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // STUDENT LIST HEADER
                  Text(
                    "Current Month Overview (${DateFormat('MMM').format(DateTime.now())})",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // STUDENT LIST
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: students.isEmpty
                        ? const Center(
                            child: Text("No students found in this class"),
                          )
                        : ListView.separated(
                            itemCount: students.length,
                            separatorBuilder: (c, i) =>
                                Divider(height: 1, color: Colors.grey[100]),
                            itemBuilder: (ctx, i) {
                              final s = students[i];
                              final adm = s['admissionNo'];
                              final pct = currentMonthStats[adm] ?? 0.0;

                              return ListTile(
                                onTap: () =>
                                    _showStudentDayWise(adm, s['name']),
                                leading: CircleAvatar(
                                  child: Text(s['name'][0].toUpperCase()),
                                ),
                                title: Text(
                                  s['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text("Adm: $adm"),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "${pct.toStringAsFixed(1)}%",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: pct < 75
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.info_outline,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 10),

                  // RANGE CALCULATOR
                  const Text(
                    "Generate Custom Report",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Date Pickers
                  Row(
                    children: [
                      Expanded(
                        child: _datePickerBtn(
                          label: startDate == null
                              ? "From Date"
                              : DateFormat('dd/MM/yy').format(startDate!),
                          icon: Icons.calendar_today,
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => startDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _datePickerBtn(
                          label: endDate == null
                              ? "To Date"
                              : DateFormat('dd/MM/yy').format(endDate!),
                          icon: Icons.event,
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2023),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => endDate = d);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Calculate Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed:
                          (startDate != null &&
                              endDate != null &&
                              !isCalculating)
                          ? () async {
                              setState(() => isCalculating = true);
                              await _calculateAttendanceForRange(
                                start: startDate!,
                                end: endDate!,
                              );
                              setState(() => isCalculating = false);
                            }
                          : null,
                      child: isCalculating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "CALCULATE REPORT",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 5. RESULTS TABLE
                  if (rangeReportData != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Result Table",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        // ✅ MODIFIED: Download button triggers image preview
                        TextButton.icon(
                          onPressed: _downloadReport,
                          icon: const Icon(
                            Icons.image,
                          ), // Changed icon to Image
                          label: const Text("View as Image"),
                        ),
                      ],
                    ),

                    // ✅ WRAPPED IN REPAINT BOUNDARY
                    RepaintBoundary(
                      key: _reportKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Added Header text to image
                                  if (startDate != null)
                                    Expanded(
                                      child: Text(
                                        "Report: ${DateFormat('dd MMM').format(startDate!)} - ${DateFormat('dd MMM').format(endDate!)}",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.grey[50],
                              child: const Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      "Student",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Adm No",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "Score",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      "%",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: rangeReportData!.length,
                              separatorBuilder: (c, i) =>
                                  const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final row = rangeReportData![i];
                                return Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(row['name']),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(row['admissionNo']),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          "${row['presentDays']}/${row['totalDays']}",
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          "${row['percentage'].toStringAsFixed(1)}%",
                                          style: TextStyle(
                                            color: row['percentage'] < 75
                                                ? Colors.red
                                                : Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ],
              ),
            ),
    );
  }

  // --- Helper Widgets ---

  Widget _datePickerBtn({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _showStudentDayWise(String admissionNo, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: _db
                .collection('attendance_final')
                .where('classId', isEqualTo: selectedClassId)
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              var docs = snapshot.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (ctx, i) {
                  final dayData = docs[i].data() as Map<String, dynamic>;
                  final date = dayData['date'] ?? 'Unknown';
                  return FutureBuilder<DocumentSnapshot>(
                    future: docs[i].reference
                        .collection('student')
                        .doc(admissionNo)
                        .get(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const SizedBox();
                      final sData = snap.data!.data() as Map<String, dynamic>?;
                      String status = sData?['status'] ?? "Absent";
                      Color color = status.toLowerCase() == 'present'
                          ? Colors.green
                          : Colors.red;
                      if (status.toLowerCase().contains('half'))
                        color = Colors.orange;
                      return ListTile(
                        dense: true,
                        title: Text(date),
                        trailing: Text(
                          status,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

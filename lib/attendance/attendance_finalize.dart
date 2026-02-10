import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Finalizes the attendance for the entire day based on Morning & Afternoon records.
  Future<void> finalizeDayAttendance({
    required String classId,
    required String date, // Format: YYYY-MM-DD
    required BuildContext context,
    bool isAuto = false, // If triggered by timer vs manual button
  }) async {
    // Session IDs
    String amSessionId = "${classId}_${date}_morning";
    String pmSessionId = "${classId}_${date}_afternoon";
    String finalDocId = "${classId}_$date";

    try {
      if (!isAuto) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => const Center(child: CircularProgressIndicator()),
        );
      }

      // --- STEP 1: FETCH DATA ---

      // A. Check if Sessions Existed (Started)
      final sessionsSnap = await Future.wait([
        _firestore.collection('attendance_session').doc(amSessionId).get(),
        _firestore.collection('attendance_session').doc(pmSessionId).get(),
      ]);

      bool amStarted = sessionsSnap[0].exists;
      bool pmStarted = sessionsSnap[1].exists;

      // Case 5: Holy-day (No sessions started) -> Ignore
      if (!amStarted && !pmStarted) {
        if (!isAuto) {
          Navigator.pop(context);
          _showSnack(context, "No sessions started today. Marked as Holiday.");
        }
        return;
      }

      // B. Fetch All Students (Master List)
      final allStudentsSnap = await _firestore
          .collection('student')
          .where('classId', isEqualTo: classId)
          .get();

      // C. Fetch Marked Students for Morning & Afternoon
      final amListSnap = await _firestore
          .collection('attendance')
          .doc(amSessionId)
          .collection('student')
          .get();
      final pmListSnap = await _firestore
          .collection('attendance')
          .doc(pmSessionId)
          .collection('student')
          .get();

      // Create Sets of IDs for fast lookup
      Set<String> amPresentIds = amListSnap.docs.map((d) => d.id).toSet();
      Set<String> pmPresentIds = pmListSnap.docs.map((d) => d.id).toSet();

      // --- STEP 2: CALCULATE LOGIC ---

      WriteBatch batch = _firestore.batch();
      DocumentReference finalReportRef = _firestore
          .collection('attendance_final')
          .doc(finalDocId);

      int countPresent = 0;
      int countAbsent = 0;
      int countHalfDay = 0;

      for (var student in allStudentsSnap.docs) {
        // ID is usually Admission Number
        String uid = student.id;
        String admissionNo = student.data()['admissionNo'] ?? uid;
        String name = student.data()['name'] ?? 'Unknown';

        // Check marking
        bool markedAM =
            amPresentIds.contains(uid) || amPresentIds.contains(admissionNo);
        bool markedPM =
            pmPresentIds.contains(uid) || pmPresentIds.contains(admissionNo);

        String status = "Absent";

        // --- 🧠 YOUR LOGIC MATRIX ---
        if (amStarted && pmStarted) {
          // Case 2: Both started, Both marked -> Present
          if (markedAM && markedPM) {
            status = "Present";
            countPresent++;
          }
          // Case 1 & 6 (Variation): Only one marked -> Half Day
          else if (markedAM || markedPM) {
            status = "Half Day";
            countHalfDay++;
          }
          // Case 6: Neither marked -> Absent
          else {
            status = "Absent";
            countAbsent++;
          }
        } else if (amStarted && !pmStarted) {
          // Case 4: Morning started, Afternoon NOT -> Morning mark counts as Present
          if (markedAM) {
            status = "Present";
            countPresent++;
          } else {
            status = "Absent";
            countAbsent++;
          }
        } else if (!amStarted && pmStarted) {
          // Case 3: Morning NOT, Afternoon started -> Afternoon mark is Half Day
          if (markedPM) {
            status = "Half Day";
            countHalfDay++;
          } else {
            status = "Absent";
            countAbsent++;
          }
        }

        // Add to batch
        DocumentReference studentFinalRef = finalReportRef
            .collection('student')
            .doc(admissionNo);
        batch.set(studentFinalRef, {
          'name': name,
          'admissionNo': admissionNo,
          'status': status,
          'morning': markedAM,
          'afternoon': markedPM,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // --- STEP 3: SAVE SUMMARY ---
      batch.set(finalReportRef, {
        'classId': classId,
        'date': date,
        'totalStudents': allStudentsSnap.docs.length,
        'presentCount': countPresent,
        'halfDayCount': countHalfDay,
        'absentCount': countAbsent,
        'isFinalized': true,
        'finalizedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!isAuto) {
        Navigator.pop(context); // Close loader
        _showSnack(
          context,
          "✅ Daily Report Finalized Successfully!",
          isSuccess: true,
        );
      }
    } catch (e) {
      debugPrint("Finalization Error: $e");
      if (!isAuto) {
        Navigator.pop(context);
        _showSnack(context, "Error: $e");
      }
    }
  }

  void _showSnack(BuildContext context, String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

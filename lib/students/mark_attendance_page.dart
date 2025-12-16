import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:darzo/services/location_service.dart';
import 'package:geolocator/geolocator.dart';

// 🔥 Backend (Python / Cloud Function logic)

/*

def verify_location(student_lat, student_lng):
    college_lat = 10.766056
    college_lng = 76.406194
    allowed_radius = 120  # meters

    distance = haversine_distance(
        student_lat, student_lng,
        college_lat, college_lng
    )

    return distance <= allowed_radius


*/
class MarkAttendancePage extends StatefulWidget {
  const MarkAttendancePage({super.key});

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  bool isLoading = false;
  bool alreadyMarked = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime now = DateTime.now();

  String get todayKey =>
      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

  // CHECK IF ATTENDANCE ALREADY MARKED
  Future<void> checkAttendance() async {
    final uid = _auth.currentUser!.uid;

    final doc = await _firestore
        .collection("attendance")
        .doc(uid)
        .collection("records")
        .doc(todayKey)
        .get();

    if (doc.exists) {
      setState(() => alreadyMarked = true);
    }
  }

  @override
  void initState() {
    super.initState();
    checkAttendance();
  }

  Future<void> markAttendance() async {
    if (alreadyMarked) return;

    setState(() => isLoading = true);

    try {
      // 1️⃣ GET LOCATION
      Position position = await LocationService.getCurrentLocation();

      final bool insideCampus = LocationService.isInsideCampus(
        studentLat: position.latitude,
        studentLng: position.longitude,
      );

      if (!insideCampus) {
        _snack("You are outside college campus");
        return;
      }

      // 2️⃣ FACE API HOOK (TEMP MOCK)
      bool faceVerified = true;
      // bool faceVerified = await FaceApi.verify(uid);

      if (!faceVerified) {
        _snack("Face verification failed");
        return;
      }

      final uid = _auth.currentUser!.uid;

      // 3️⃣ SAVE ATTENDANCE
      await _firestore
          .collection("attendance")
          .doc(uid)
          .collection("records")
          .doc(todayKey)
          .set({
            "value": 1,
            "markedBy": "face",
            "latitude": position.latitude,
            "longitude": position.longitude,
            "locationVerified": true,
            "markedAt": FieldValue.serverTimestamp(),
          });

      setState(() => alreadyMarked = true);
      _snack("Attendance marked successfully");
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3F7EDB),
      appBar: AppBar(
        title: const Text("Mark Attendance"),
        backgroundColor: const Color(0xFF3F7EDB),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.face, size: 80, color: Color(0xFF3F7EDB)),
                const SizedBox(height: 16),

                const Text(
                  "Face Attendance",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                Text(
                  "Date: ${now.day}/${now.month}/${now.year}",
                  style: const TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 24),

                // STATUS
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: alreadyMarked
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alreadyMarked
                        ? "Attendance already marked"
                        : "Attendance not marked",
                    style: TextStyle(
                      color: alreadyMarked ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: alreadyMarked || isLoading
                        ? null
                        : markAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F7EDB),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "MARK ATTENDANCE",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

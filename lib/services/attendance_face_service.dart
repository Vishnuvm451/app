import 'dart:io';
import 'package:http/http.dart' as http;

class AttendanceFaceService {
  static const String baseUrl = "http://10.70.229.181:8000";

  static Future<bool> markAttendance({
    required String studentUid,
    required String classId,
    required String sessionType, // morning | afternoon
    required File imageFile,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/attendance/mark");

      final request = http.MultipartRequest("POST", uri)
        ..fields['student_uid'] = studentUid
        ..fields['class_id'] = classId
        ..fields['session_type'] = sessionType
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return true;
      } else {
        // Only show the error message from server
        throw Exception(responseBody);
      }
    } catch (e) {
      print("Attendance Error: $e");
      rethrow;
    }
  }
}

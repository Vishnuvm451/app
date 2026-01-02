import 'dart:io';
import 'package:http/http.dart' as http;

class AttendanceFaceService {
  // ⚠️ CHANGE THIS TO YOUR SERVER IP
  static const String baseUrl = "http://YOUR_SERVER_IP:8000";

  static Future<bool> markAttendance({
    required String studentUid,
    required String classId,
    required String sessionType, // morning | afternoon
    required File imageFile,
  }) async {
    final uri = Uri.parse("$baseUrl/attendance/mark");

    final request = http.MultipartRequest("POST", uri)
      ..fields['student_uid'] = studentUid
      ..fields['class_id'] = classId
      ..fields['session_type'] = sessionType
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final response = await request.send();
    final statusCode = response.statusCode;

    if (statusCode == 200) {
      return true;
    } else {
      final body = await response.stream.bytesToString();
      throw Exception("Attendance failed: $body");
    }
  }
}

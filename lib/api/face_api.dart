import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// ======================================================
/// API ENDPOINTS
/// ======================================================
class ApiEndpoints {
  static const String baseUrl = "https://darzo-backend-api.onrender.com";

  /// Face Registration
  static const String registerFace = "$baseUrl/face/register";

  /// Parent Face Verify
  static const String verifyParent = "$baseUrl/face/verify/parent";

  /// Student Attendance Verify
  static const String verifyAttendance = "$baseUrl/face/verify";
}

/// ======================================================
/// API SERVICES
/// ======================================================
class ApiServices {
  // 90s timeout for "sleeping" Render servers
  static const int _timeoutSeconds = 60;

  /// ------------------------------------------------------
  /// CORE MULTIPART UPLOAD
  /// ------------------------------------------------------
  static Future<Map<String, dynamic>> _uploadImages({
    required String url,
    required Map<String, String> fields,
    required List<Uint8List> images,
    required List<String> imageNames,
  }) async {
    try {
      print("\n📤 Uploading to: $url");
      print("   Fields: $fields");
      print("   Images: ${images.length}");

      // ---------- VALIDATION ----------
      for (int i = 0; i < images.length; i++) {
        if (images[i].isEmpty) {
          throw Exception("Image ${i + 1} is empty (0 bytes)");
        }
      }

      final uri = Uri.parse(url);
      final request = http.MultipartRequest('POST', uri);

      // ---------- FORM FIELDS ----------
      request.fields.addAll(fields);

      // ---------- IMAGES ----------
      for (int i = 0; i < images.length; i++) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'images', // ✅ Changed from 'images[]' to 'images' for Python/FastAPI
            images[i],
            filename: imageNames[i],
            contentType: MediaType('image', 'jpeg'),
          ),
        );
      }

      print("📨 Sending request...");
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: _timeoutSeconds),
        onTimeout: () {
          throw TimeoutException(
            "Request timeout after $_timeoutSeconds seconds",
          );
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      print("📥 Status: ${response.statusCode}");

      if (response.body.isEmpty) {
        return {
          'success': false,
          'message': "Empty response from server (${response.statusCode})",
        };
      }

      final Map<String, dynamic> responseData =
          jsonDecode(response.body) as Map<String, dynamic>;

      // ---------- SUCCESS ----------
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': responseData};
      }

      // ---------- ERROR EXTRACTION ----------
      String errorMsg = "Error ${response.statusCode}";

      if (responseData['detail'] != null) {
        final detail = responseData['detail'];
        if (detail is List) {
          errorMsg = detail
              .map((e) => e is Map ? (e['msg'] ?? e.toString()) : e.toString())
              .join(", ");
        } else if (detail is Map) {
          errorMsg = detail['message'] ?? detail['error'] ?? detail.toString();
        } else {
          errorMsg = detail.toString();
        }
      } else if (responseData['message'] != null) {
        errorMsg = responseData['message'];
      }

      return {'success': false, 'message': errorMsg};
    } on TimeoutException catch (e) {
      print("⏱ TIMEOUT: $e");
      return {
        'success': false,
        'message': "Server is waking up. Please try again in 10s.",
      };
    } catch (e) {
      print("❌ EXCEPTION: $e");
      return {'success': false, 'message': "Connection error: $e"};
    }
  }

  /// ------------------------------------------------------
  /// 1. REGISTER FACE
  /// ------------------------------------------------------
  static Future<Map<String, dynamic>> registerFace({
    required String admissionNo,
    required String authUid, // Required by backend
    required List<Uint8List> images,
  }) async {
    if (admissionNo.trim().isEmpty)
      return {'success': false, 'message': 'Missing Admission No'};

    return _uploadImages(
      url: ApiEndpoints.registerFace,
      fields: {'admission_no': admissionNo.trim(), 'auth_uid': authUid.trim()},
      images: images,
      imageNames: const ['straight.jpg', 'left.jpg', 'right.jpg'],
    );
  }

  /// ------------------------------------------------------
  /// 2. STUDENT ATTENDANCE VERIFY (FIXED)
  /// ------------------------------------------------------
  static Future<Map<String, dynamic>> markAttendance({
    required String admissionNo,
    required String sessionId, // ✅ Added
    required String studentId, // ✅ Added
    required List<Uint8List> images,
  }) async {
    if (admissionNo.trim().isEmpty)
      return {'success': false, 'message': 'Missing Admission No'};

    return _uploadImages(
      url: ApiEndpoints.verifyAttendance,
      fields: {
        'admission_no': admissionNo.trim(),
        'session_id': sessionId.trim(), // ✅ Passed to backend
        'student_id': studentId.trim(), // ✅ Passed to backend
      },
      images: images,
      imageNames: const ['straight.jpg', 'left.jpg', 'right.jpg'],
    );
  }

  /// ------------------------------------------------------
  /// 3. PARENT FACE VERIFY
  /// ------------------------------------------------------
  static Future<Map<String, dynamic>> verifyParent({
    required String admissionNo,
    required List<Uint8List> images,
  }) async {
    if (admissionNo.trim().isEmpty)
      return {'success': false, 'message': 'Missing Admission No'};

    return _uploadImages(
      url: ApiEndpoints.verifyParent,
      fields: {'admission_no': admissionNo.trim()},
      images: images,
      imageNames: const ['straight.jpg', 'left.jpg', 'right.jpg'],
    );
  }
}

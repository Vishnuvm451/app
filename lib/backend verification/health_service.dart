import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class HealthService {
  static Future<bool> checkBackend() async {
    try {
      final response = await http
          .get(Uri.parse("${ApiConfig.baseUrl}/"))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'ok';
      }
    } catch (e) {
      return false;
    }
    return false;
  }
}

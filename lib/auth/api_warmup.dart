import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

Future<void> warmUpApiServer() async {
  try {
    debugPrint("🔥 Warming up API server...");

    final response = await http
        .get(Uri.parse("https://darzo-api.onrender.com/health"))
        .timeout(const Duration(seconds: 12));

    debugPrint("✅ API warm-up done: ${response.statusCode}");
  } on TimeoutException {
    debugPrint("⏳ API warm-up timeout (server probably sleeping)");
  } catch (e) {
    debugPrint("⚠️ API warm-up error: $e");
  }
}

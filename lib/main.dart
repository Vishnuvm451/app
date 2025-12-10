// main.dart
// Minimal Flutter app that opens the Login UI as the first screen.
// Replace the default main.dart in a new Flutter project with this file.

import 'package:darzo/login/login.dart';
import 'package:flutter/material.dart';

// import 'package:firebase_core/firebase_core.dart';

void main() async {
  // WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Change global theme colors here if you want to alter the look app-wide.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Darzo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2196F3),
        scaffoldBackgroundColor: const Color(0xFF2196F3),
        useMaterial3: false,
      ),
      home: const LoginPage(), // <-- App opens to this page
    );
  }
}

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// =====================================================
// BACKGROUND HANDLER (Top Level)
// =====================================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("📩 [BACKGROUND] Message: ${message.notification?.title}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> initialize({required String role, required String id}) async {
    if (_isInitialized) return;

    try {
      // 1. Request Permission
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        announcement: true,
      );

      // 2. Setup Local Notifications (Android & iOS)
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();

      await _localNotif.initialize(
        const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: (response) {
          debugPrint("👆 Local notification tapped: ${response.payload}");
        },
      );

      // 3. Create Channel (Required for Android)
      await _createNotificationChannel();

      // 4. Handle Background Messages
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 5. Get Token & Save (UPDATED FOR YOUR SCREENSHOT)
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint("🔑 FCM Token: $token");
        await _saveTokenToFirestore(token: token, id: id, role: role);
      }

      // 6. Listen for Token Refresh
      _fcm.onTokenRefresh.listen((token) {
        _saveTokenToFirestore(
          token: token,
          role: role, // your role variable
          id: id, // your user id
        );
      });

      // 7. FOREGROUND LISTENER (Crucial for Local Notifications)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("📬 [FOREGROUND] Notification received");

        // If the app is open, FCM doesn't show a notification by default.
        // We must trigger a LOCAL notification manually.
        if (message.notification != null) {
          _showLocalNotification(
            title: message.notification!.title ?? 'New Message',
            body: message.notification!.body ?? '',
          );
        }
      });

      _isInitialized = true;
      debugPrint("✅ NotificationService Initialized");
    } catch (e) {
      debugPrint("❌ Notification Init Error: $e");
    }
  }

  // =====================================================
  // 1. SAVE TOKEN (MATCHING YOUR SCREENSHOT)
  // =====================================================
  Future<void> _saveTokenToFirestore({
    required String token,
    required String role,
    required String id,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = FirebaseFirestore.instance.collection('fcm').doc(role);

      // 🔑 Update map: fcm_array.{id} = token
      await docRef.set({
        'fcm_array': {id: token},
      }, SetOptions(merge: true));

      debugPrint("✅ Token saved in fcm/$role under key $id");
    } catch (e) {
      debugPrint("❌ Error saving token: $e");
    }
  }

  // =====================================================
  // 2. SHOW LOCAL NOTIFICATION
  // =====================================================
  Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    const androidDetail = AndroidNotificationDetails(
      'announcements', // ID must match the channel created
      'Announcements',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetail = DarwinNotificationDetails();

    await _localNotif.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(android: androidDetail, iOS: iosDetail),
    );
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'announcements',
      'Announcements',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }
}

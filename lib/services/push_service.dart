import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:task_manager_crud_app/app_navigator.dart';

class PushService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final ValueNotifier<List<RemoteMessage>> foreGroundMessage =
      ValueNotifier<List<RemoteMessage>>([]);

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // On iOS the system must not show the foreground FCM message itself;
    // NotificationService shows a local notification instead.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // FCM Token
    await getToken();

    // Token refresh
    _messaging.onTokenRefresh.listen((String token) {
      debugPrint('FCM Token refreshed: $token');
      saveTokenForCurrentUser(token);
    });

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.messageId}, ${message.data}');

      foreGroundMessage.value = [...foreGroundMessage.value, message];
    });

    // App opened from background
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
  }

  // App opened from terminated state
  static Future<void> handleLaunchMessage() async {
    final RemoteMessage? message = await _messaging.getInitialMessage();

    if (message != null) {
      _openFromMessage(message);
    }
  }

  static void _openFromMessage(RemoteMessage remote) {
    AppNavigator.openTask(remote.data['taskId']?.toString());
  }

  static Future<String?> getToken() async {
    try {
      final String? token = await _messaging.getToken();

      debugPrint('FCM Token: $token');

      return token;
    } catch (e) {
      debugPrint('Unable to get FCM Token: $e');
      return null;
    }
  }

  // Save the device token in Firestore: users/{uid}.fcmToken
  static Future<void> saveTokenForCurrentUser([String? token]) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final String? value = token ?? await getToken();

      if (value == null) return;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'fcmToken': value,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Unable to save FCM token: $e');
    }
  }
}

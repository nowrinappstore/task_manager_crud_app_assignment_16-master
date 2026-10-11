import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../app_navigator.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static bool _foregroundListenerInitialized = false;

  // One Android channel per priority (sound/importance differ per channel).
  // 'Class_channel' is also the default channel set in AndroidManifest.xml,
  // so notifications shown by Firebase in the background use it too.
  static const AndroidNotificationChannel _mediumChannel =
      AndroidNotificationChannel(
        'Class_channel',
        'Class Notifications',
        description: 'Notifications from Task Manager',
        importance: Importance.max,
      );

  static const AndroidNotificationChannel _highChannel =
      AndroidNotificationChannel(
        'task_high',
        'High priority tasks',
        description: 'Urgent task notifications',
        importance: Importance.max,
      );

  static const AndroidNotificationChannel _lowChannel =
      AndroidNotificationChannel(
        'task_low',
        'Low priority tasks',
        description: 'Quiet task notifications',
        importance: Importance.low,
      );

  static NotificationDetails _detailsFor(String? priority) {
    final AndroidNotificationChannel channel = switch (priority) {
      'high' => _highChannel,
      'low' => _lowChannel,
      _ => _mediumChannel,
    };

    final Priority androidPriority = switch (priority) {
      'high' => Priority.max,
      'low' => Priority.low,
      _ => Priority.high,
    };

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: androidPriority,
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  // Initialize Local Notifications
  static Future<void> init() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

    const InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: onTap,
      onDidReceiveBackgroundNotificationResponse: onBackgroundTap,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(_mediumChannel);
    await android?.createNotificationChannel(_highChannel);
    await android?.createNotificationChannel(_lowChannel);

    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    _initialized = true;
    debugPrint('Local notifications initialized.');
  }

  // Tap on a local notification (app running): open the Task List and,
  // when the payload is a task ID, the related task.
  @pragma('vm:entry-point')
  static void onTap(NotificationResponse response) {
    final payload = response.payload;
    debugPrint('Local notification tapped. Payload: $payload');

    AppNavigator.openTask(payload);
  }

  // Runs in a background isolate, so it must not touch the UI.
  @pragma('vm:entry-point')
  static void onBackgroundTap(NotificationResponse response) {
    debugPrint('Background notification response: ${response.payload}');
  }

  // App was launched (from terminated state) by tapping a local notification
  static Future<void> handleLaunchNotification() async {
    final details = await _plugin.getNotificationAppLaunchDetails();

    if (details?.didNotificationLaunchApp ?? false) {
      AppNavigator.openTask(details!.notificationResponse?.payload);
    }
  }

  // Initialize Firebase Cloud Messaging
  static Future<void> initializeFCM() async {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('FCM permission: ${settings.authorizationStatus}');

    final token = await getFCMToken();

    debugPrint('========== FCM TOKEN ==========');
    debugPrint(token ?? 'FCM token unavailable');
    debugPrint('===============================');

    messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed: $newToken');
    });
  }

  // Get FCM Token
  static Future<String?> getFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('Unable to get FCM token: $e');
      return null;
    }
  }

  // Foreground: FCM does not show a notification while the app is open,
  // so we receive the message and show a LOCAL notification ourselves.
  static void listenForegroundMessages() {
    if (_foregroundListenerInitialized) return;
    _foregroundListenerInitialized = true;

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final String priority = (message.data['priority'] ?? 'medium')
          .toString()
          .toLowerCase();

      String title =
          message.notification?.title ??
          message.data['title']?.toString() ??
          'New Task';

      final String body =
          message.notification?.body ??
          message.data['body']?.toString() ??
          'You have a new task';

      final String? taskId = message.data['taskId']?.toString();

      // Different look for high priority tasks
      if (priority == 'high') {
        title = '🔥 $title';
      }

      await showNotification(
        id: message.messageId?.hashCode ?? message.hashCode,
        title: title,
        body: body,
        payload: taskId,
        priority: priority,
      );

      debugPrint('Foreground notification displayed: $title');
    });
  }

  // Show Immediate Local Notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? priority,
  }) async {
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: _detailsFor(priority),
      payload: payload,
    );
  }

  // Schedule Notification Internally
  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    String? payload,
    String? priority,
  }) async {
    Future<void> run(AndroidScheduleMode mode) {
      return _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: _detailsFor(priority),
        androidScheduleMode: mode,
        payload: payload,
      );
    }

    try {
      await run(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (e) {
      debugPrint('Exact alarm failed; trying inexact mode: $e');
      await run(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  // Schedule Task Reminder (payload = task ID, so a tap opens the task)
  static Future<void> scheduleTaskNotification({
    required int id,
    required String title,
    required DateTime scheduledDate,
    String? taskId,
    String? priority,
  }) async {
    final scheduledTime = tz.TZDateTime.from(scheduledDate, tz.local);

    if (!scheduledTime.isAfter(tz.TZDateTime.now(tz.local))) {
      debugPrint('Task due date has already passed.');
      return;
    }

    await _schedule(
      id: id,
      title: title,
      body: 'Your task is due now.',
      when: scheduledTime,
      payload: taskId ?? id.toString(),
      priority: priority,
    );

    debugPrint('Task notification scheduled: $id');
  }

  // Schedule Notification After a Delay
  static Future<void> scheduleIn({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    String? payload,
  }) async {
    final scheduledTime = tz.TZDateTime.now(tz.local).add(delay);

    await _schedule(
      id: id,
      title: title,
      body: body,
      when: scheduledTime,
      payload: payload,
    );

    debugPrint('Notification scheduled in ${delay.inSeconds}s. ID: $id');
  }

  // Convert Task ID into a Notification ID
  static int notificationIdFor(String taskId) {
    int hash = 0;

    for (final unit in taskId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }

    // Keep notification ID positive and non-zero.
    return hash == 0 ? 1 : hash;
  }

  // Cancel Task Reminder
  static Future<void> cancelTaskNotification({required int id}) async {
    await _plugin.cancel(id: id);
    debugPrint('Task notification cancelled: $id');
  }

  // Cancel All Notifications
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('All notifications cancelled.');
  }
}

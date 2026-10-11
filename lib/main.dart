import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'package:task_manager_crud_app/app_navigator.dart';
import 'package:task_manager_crud_app/services/auth_services.dart';
import 'package:task_manager_crud_app/services/notification_service.dart';
import 'package:task_manager_crud_app/services/push_service.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'firebase_options.dart';

class AppStartup {
  static bool firebaseReady = false;
  static String? firebaseError;
}

// Background / terminated FCM handler (must be top-level).
// Messages with a `notification` block are shown by the system itself.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('Background FCM message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    AppStartup.firebaseReady = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    AppStartup.firebaseError = e.toString();
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize Services
  if (AppStartup.firebaseReady) {
    try {
      // Local notification initialization
      await NotificationService.init();

      // FCM initialization and token setup
      await PushService.init();

      // Show local notification for foreground FCM messages
      NotificationService.listenForegroundMessages();

      // Initialize Google Sign-In (once)
      await AuthService.initGoogle();
    } catch (e, stackTrace) {
      debugPrint('Service initialization failed: $e');
      debugPrint('$stackTrace');
    }
  }

  runApp(const MyApp());

  // Handle a notification that opened the app from the terminated state
  if (AppStartup.firebaseReady) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushService.handleLaunchMessage(); // FCM notification tapped
      NotificationService.handleLaunchNotification(); // local notification tapped
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigator.key,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: !AppStartup.firebaseReady
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Firebase initialization failed:\n'
                    '${AppStartup.firebaseError ?? "Unknown error"}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : StreamBuilder<User?>(
              stream: AuthService().authState,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return const Scaffold(
                    body: Center(child: Text('Authentication error occurred.')),
                  );
                }

                if (snapshot.hasData) {
                  return const HomeScreen();
                }

                return const LoginScreen();
              },
            ),
    );
  }
}
